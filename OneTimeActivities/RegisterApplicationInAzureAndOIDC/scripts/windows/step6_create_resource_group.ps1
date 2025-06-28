# step6_create_resource_group.ps1
#
# run this script because policy prevents resource group creation by service principals.
# CI/CD pipelines and automation scripts should not create resource groups directly.
# Instead, use this script to create the resource group and update the inventory.

param(
    [string]$rgname,
    [string]$location = "",
    [string]$servicePrincipalId = ""
)

function Resolve-ScriptPath {
    $script:ScriptDir = $PSScriptRoot
    if (-not $script:ScriptDir) {
        $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    $script:ProjectRoot = (Get-Item $script:ScriptDir).Parent.Parent.Parent.Parent.FullName
    $script:TFVarsFile = Join-Path $script:ProjectRoot "terraform/validation/terraform.tfvars"
    $script:CredsFile = Join-Path $script:ProjectRoot ".env/azure-credentials.json"
}

Resolve-ScriptPath

if (-not $rgname) {
    Write-Error "Resource group name is required. Use -rgname <resource-group-name>."
    exit 1
}

# --- LOAD LOCATION AND TAGS FROM TFVARS IF NOT PROVIDED ---
if (-not $location -and (Test-Path $script:TFVarsFile)) {
    $location = Select-String -Path $script:TFVarsFile -Pattern '^[\s]*dev_location[\s]*=[\s]*"([^"]+)"' | ForEach-Object {
        $_.Matches[0].Groups[1].Value
    }
}
if (-not $location) { $location = "canadacentral" }

# Parse common_tags from tfvars robustly
$tags = @{}
if (Test-Path $script:TFVarsFile) {
    $inTags = $false
    Get-Content $script:TFVarsFile | ForEach-Object {
        if ($_ -match '^[\s]*common_tags[\s]*=[\s]*\{') { $inTags = $true; return }
        if ($inTags -and $_ -match '^[\s]*\}') { $inTags = $false; return }
        if ($inTags -and $_ -match '^[\s]*([a-zA-Z0-9_]+)[\s]*=[\s]*"([^"]*)"') {
            $tags[$matches[1]] = $matches[2]
        }
    }
}

# --- CREATE RESOURCE GROUP ---
if ($tags.Count -gt 0) {
    $tagArgs = $tags.GetEnumerator() | ForEach-Object { "$_=$($tags[$_])" } | Out-String
    Write-Host "Creating resource group: $rgname in $location with tags..."
    az group create --name $rgname --location $location --tags $($tags.GetEnumerator() | ForEach-Object {"$_=$($tags[$_])"})
} else {
    Write-Host "Creating resource group: $rgname in $location..."
    az group create --name $rgname --location $location
}

# --- FETCH RESOURCE GROUP DETAILS ---
$rgJson = az group show --name $rgname -o json | ConvertFrom-Json
$rgId = $rgJson.id
$rgLocation = $rgJson.location

# --- UPDATE FULL INVENTORY JSON ---
$inventoryFile = Join-Path $script:ProjectRoot ".env/azure_full_inventory.json"
if (-not (Test-Path $inventoryFile)) {
    $init = @{ resourceGroups = @(); storageAccounts = @(); blobContainers = @() } | ConvertTo-Json
    $init | Set-Content $inventoryFile
}
$inventory = Get-Content $inventoryFile | ConvertFrom-Json
$inventory.resourceGroups = @($inventory.resourceGroups | Where-Object { $_.name -ne $rgname })
$inventory.resourceGroups += @{ name = $rgname; id = $rgId; location = $rgLocation }
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryFile
Write-Host "`u2714 Resource group '$rgname' recorded in azure_full_inventory.json."

# --- FETCH TAGS FROM AZURE ---
$tagsJson = az group show --name $rgname --query tags -o json
if (-not $tagsJson -or $tagsJson -eq "null") {
    Write-Warning "No tags found for resource group $rgname. TAGS_JSON is empty or null."
} else {
    Write-Host "Debug: TAGS_JSON from Azure: $tagsJson"
}

# --- UPDATE CREDENTIALS JSON ---
if (Test-Path $script:CredsFile) {
    Write-Host "✅ .env/azure-credentials.json found. No tag update performed."
} else {
    Write-Warning "Credentials file $($script:CredsFile) not found. Skipping JSON update."
}

# --- ASSIGN ROLES TO SERVICE PRINCIPAL OBJECT ID AT RESOURCE GROUP SCOPE ---
# Parse dev_service_principal_id from tfvars if available
$servicePrincipalId = ""
if (Test-Path $script:TFVarsFile) {
    $spLine = Select-String -Path $script:TFVarsFile -Pattern 'dev_service_principal_id\s*=\s*"([^"]+)"' | ForEach-Object {
        $_.Matches[0].Groups[1].Value
    }
    if ($spLine) { $servicePrincipalId = $spLine }
}
# If still empty, try to look up by display name
if (-not $servicePrincipalId) {
    $servicePrincipalId = az ad sp list --display-name "ag-pssg-azure-files-poc-ServicePrincipal" --query "[0].id" -o tsv
}
# If still empty, prompt the user
if (-not $servicePrincipalId) {
    $servicePrincipalId = Read-Host "Enter the service principal (object) ID to assign roles to"
}

$subscriptionId = az account show --query id -o tsv
$scope = "/subscriptions/$subscriptionId/resourceGroups/$rgname"

# Assign Storage Account Contributor role
Write-Host "Assigning 'Storage Account Contributor' role to $servicePrincipalId at resource group $rgname..."
az role assignment create --assignee $servicePrincipalId --role "Storage Account Contributor" --scope $scope

# Assign custom role (ag-pssg-azure-files-poc-dev-role-assignment-writer)
Write-Host "Assigning 'ag-pssg-azure-files-poc-dev-role-assignment-writer' role to $servicePrincipalId at resource group $rgname..."
az role assignment create --assignee $servicePrincipalId --role "ag-pssg-azure-files-poc-dev-role-assignment-writer" --scope $scope

Write-Host "✅ Resource group '$rgname' created and roles assigned."
