# Filename: scripts/bicep/teardown-subnet-vm.ps1
# Teardown VM Subnet
# This script removes the VM subnet created for the AI Foundry Landing Zone

# Load environment variables
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "azure.env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Variables
$rgNetworking = $env:RG_NETWORKING
$vnetName = $env:VNET_SPOKE
$subnetName = $env:SUBNET_VM

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down VM Subnet" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $rgNetworking"
Write-Host "VNet: $vnetName"
Write-Host "Subnet: $subnetName"
Write-Host ""

# Check if subnet exists
Write-Host "Checking if subnet exists..." -ForegroundColor Yellow
$subnet = az network vnet subnet show `
    --resource-group $rgNetworking `
    --vnet-name $vnetName `
    --name $subnetName `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($subnet)) {
    Write-Host "Subnet '$subnetName' does not exist. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "Subnet found: $subnet" -ForegroundColor Green

# Check if subnet has any attached resources
Write-Host ""
Write-Host "Checking for attached resources..." -ForegroundColor Yellow
$attachedResources = az network vnet subnet show `
    --resource-group $rgNetworking `
    --vnet-name $vnetName `
    --name $subnetName `
    --query "{nics: ipConfigurations[].id, privateEndpoints: privateEndpoints[].id}" `
    --output json | ConvertFrom-Json

if ($attachedResources.nics -or $attachedResources.privateEndpoints) {
    Write-Host ""
    Write-Host "⚠️  ERROR: Subnet has attached resources and cannot be deleted:" -ForegroundColor Red
    if ($attachedResources.nics) {
        Write-Host "  - Network Interfaces: $($attachedResources.nics.Count)" -ForegroundColor Yellow
    }
    if ($attachedResources.privateEndpoints) {
        Write-Host "  - Private Endpoints: $($attachedResources.privateEndpoints.Count)" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Remove all attached resources before deleting the subnet." -ForegroundColor Yellow
    exit 1
}

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the VM subnet." -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete subnet
Write-Host ""
Write-Host "Deleting subnet '$subnetName'..." -ForegroundColor Yellow
az network vnet subnet delete `
    --resource-group $rgNetworking `
    --vnet-name $vnetName `
    --name $subnetName

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Subnet '$subnetName' deleted successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Failed to delete subnet. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
