# step6_create_resource_group.ps1
# Only creates the resource group and updates .env/azure-credentials.json with its metadata (no tags update in JSON).

param(
    [string]$rgname,
    [string]$location = ""
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

# Load location from tfvars if not provided
if (-not $location -and (Test-Path $script:TFVarsFile)) {
    $location = Select-String -Path $script:TFVarsFile -Pattern '^\s*dev_location\s*=\s*"([^"]+)"' | ForEach-Object {
        $_.Matches[0].Groups[1].Value
    }
}
if (-not $location) { $location = "canadacentral" }

# Parse tags from tfvars
$tags = @{}
if (Test-Path $script:TFVarsFile) {
    $inTags = $false
    Get-Content $script:TFVarsFile | ForEach-Object {
        if ($_ -match '^\s*common_tags\s*=\s*\{') { $inTags = $true; return }
        if ($inTags -and $_ -match '^\s*\}') { $inTags = $false; return }
        if ($inTags -and $_ -match '^\s*([a-zA-Z0-9_]+)\s*=\s*"([^"]*)"') {
            $tags[$matches[1]] = $matches[2]
        }
    }
}

# Create resource group with tags
if ($tags.Count -gt 0) {
    $tagArgs = $tags.GetEnumerator() | ForEach-Object { "--tags $_=$($tags[$_])" } | Out-String
    Write-Host "Creating resource group: $rgname in $location with tags..."
    az group create --name $rgname --location $location --tags @{$($tags.GetEnumerator() | ForEach-Object {"'$_'='$($tags[$_])'"})}
} else {
    Write-Host "Creating resource group: $rgname in $location..."
    az group create --name $rgname --location $location
}

# Fetch tags from Azure for debug
$tagsJson = az group show --name $rgname --query tags -o json
if (-not $tagsJson -or $tagsJson -eq "null") {
    Write-Warning "No tags found for resource group $rgname."
} else {
    Write-Host "Debug: TAGS_JSON from Azure: $tagsJson"
}

# Do not update tags in credentials JSON as per user request
if (Test-Path $script:CredsFile) {
    Write-Host "✅ .env/azure-credentials.json found. No tag update performed."
} else {
    Write-Warning "Credentials file $($script:CredsFile) not found. Skipping JSON update."
}

# Update inventory JSON (add or update resource group entry)
$inventoryFile = Join-Path $script:ProjectRoot ".env/azure_full_inventory.json"
if (-not (Test-Path $inventoryFile)) {
    $init = @{ resourceGroups = @(); storageAccounts = @(); blobContainers = @() } | ConvertTo-Json
    $init | Set-Content $inventoryFile
}
$inventory = Get-Content $inventoryFile | ConvertFrom-Json
$inventory.resourceGroups = @($inventory.resourceGroups | Where-Object { $_.name -ne $rgname })
$inventory.resourceGroups += @{ name = $rgname; id = $rgJson.id; location = $rgJson.location }
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryFile
Write-Host "`u2714 Resource group '$rgname' recorded in azure_full_inventory.json."

Write-Host "✅ Resource group '$rgname' created and script complete."
