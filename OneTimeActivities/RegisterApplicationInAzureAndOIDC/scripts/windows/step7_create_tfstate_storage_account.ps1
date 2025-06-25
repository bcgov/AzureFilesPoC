# step7_create_tfstate_storage_account.ps1
# PowerShell script to create a storage account and blob container, and update the inventory JSON
param(
    [Parameter(Mandatory=$true)]
    [string]$rgname,
    [Parameter(Mandatory=$true)]
    [string]$saname,
    [Parameter(Mandatory=$true)]
    [string]$containername,
    [string]$location = "canadacentral"
)

$projectRoot = Resolve-Path "$PSScriptRoot/../../../../"
$inventoryFile = Join-Path $projectRoot ".env/azure_full_inventory.json"

# Create storage account
Write-Host "Creating storage account: $saname in resource group $rgname at $location..."
$saJson = az storage account create --name $saname --resource-group $rgname --location $location --sku Standard_LRS --kind StorageV2 --allow-blob-public-access false --min-tls-version TLS1_2 --output json | ConvertFrom-Json
$saId = $saJson.id
$saLocation = $saJson.primaryLocation
Write-Host "`u2714 Storage account '$saname' created."

# Create blob container
Write-Host "Creating blob container: $containername in storage account $saname..."
az storage container create --name $containername --account-name $saname --output json | Out-Null

# Ensure inventory file exists
if (-not (Test-Path $inventoryFile)) {
    $init = @{ resourceGroups = @(); storageAccounts = @(); blobContainers = @() } | ConvertTo-Json
    $init | Set-Content $inventoryFile
}

# Update storageAccounts and blobContainers arrays
$inventory = Get-Content $inventoryFile | ConvertFrom-Json
$inventory.storageAccounts = @($inventory.storageAccounts | Where-Object { $_.name -ne $saname })
$inventory.storageAccounts += @{ name = $saname; id = $saId; location = $saLocation }
$inventory.blobContainers = @($inventory.blobContainers | Where-Object { $_.name -ne $containername -or $_.storageAccount -ne $saname })
$inventory.blobContainers += @{ name = $containername; storageAccount = $saname }
$inventory | ConvertTo-Json -Depth 10 | Set-Content $inventoryFile

Write-Host "`u2714 Storage account '$saname' and blob container '$containername' recorded in azure_full_inventory.json."
Write-Host "All required Terraform state backend resources are created."
