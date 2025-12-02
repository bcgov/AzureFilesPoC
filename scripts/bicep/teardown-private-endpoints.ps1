# Filename: scripts/bicep/teardown-private-endpoints.ps1
# Teardown Private Endpoints for Storage, Key Vault, and Azure AI Foundry
# This script removes the private endpoints created for secure connectivity
#
# Private Endpoints Removed:
# 1. Storage Account PE (pe-storage-ag-pssg-azure-files)
# 2. Key Vault PE (pe-keyvault-ag-pssg-azure-files)
# 3. Azure AI Foundry PE (pe-foundry-ag-pssg-azure-files)
#
# VERIFICATION: After teardown, services will be accessible via public endpoints only

param(
    [switch]$SkipStorage = $false,
    [switch]$SkipKeyVault = $false,
    [switch]$SkipFoundry = $false
)

# Load environment variables from azure.env
$envFile = "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        # Skip comments and empty lines
        if ($_ -match '^\s*$' -or $_ -match '^\s*#') {
            return
        }
        # Parse key=value pairs, handling quoted values and comments
        if ($_ -match '^\s*([^=]+)\s*=\s*(.+?)\s*(#.*)?$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove surrounding quotes if present
            if ($value -match '^"(.+)"$') {
                $value = $matches[1]
            }
            Set-Item -Path "env:$key" -Value $value
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

# Variables from environment
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RG_AZURE_FILES

# Private Endpoint names (match deploy script)
$peStorageName = "pe-storage-ag-pssg-azure-files"
$peKeyVaultName = "pe-keyvault-ag-pssg-azure-files"
$peFoundryName = "pe-foundry-ag-pssg-azure-files"

# Validate required variables
if (-not $subscriptionId -or -not $resourceGroup) {
    Write-Host "Error: Missing required environment variables (AZURE_SUBSCRIPTION_ID, RG_AZURE_FILES)" -ForegroundColor Red
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Private Endpoints" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Skip Storage: $SkipStorage" -ForegroundColor Gray
Write-Host "Skip Key Vault: $SkipKeyVault" -ForegroundColor Gray
Write-Host "Skip Foundry: $SkipFoundry" -ForegroundColor Gray
Write-Host ""

# Ensure CLI and subscription context
az account set --subscription $subscriptionId

# Function to delete private endpoint
function Remove-PrivateEndpoint {
    param(
        [string]$peName,
        [string]$description
    )

    Write-Host "----------------------------------------" -ForegroundColor Yellow
    Write-Host "Removing $description Private Endpoint" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    # Check if private endpoint exists
    Write-Host "Checking if Private Endpoint '$peName' exists..." -ForegroundColor Gray
    $peExists = az network private-endpoint show `
        --name $peName `
        --resource-group $resourceGroup `
        --query "id" -o tsv 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($peExists)) {
        Write-Host "Private Endpoint '$peName' does not exist. Skipping." -ForegroundColor Yellow
        return
    }

    Write-Host "Private Endpoint found: $peExists" -ForegroundColor Green

    # Confirm deletion
    Write-Host ""
    Write-Host "⚠️  WARNING: This will remove the private endpoint for $description." -ForegroundColor Red
    Write-Host "Services will only be accessible via public endpoints after removal." -ForegroundColor Red
    $confirmation = Read-Host "Type 'yes' to confirm deletion of $peName"

    if ($confirmation -ne 'yes') {
        Write-Host "Deletion of $peName cancelled." -ForegroundColor Yellow
        return
    }

    # Delete private endpoint
    Write-Host ""
    Write-Host "Deleting Private Endpoint '$peName'..." -ForegroundColor Yellow
    az network private-endpoint delete `
        --name $peName `
        --resource-group $resourceGroup `
        --yes

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Private Endpoint '$peName' deleted successfully!" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to delete Private Endpoint '$peName'. Check error messages above." -ForegroundColor Red
    }
    Write-Host ""
}

# Remove Storage PE
if (-not $SkipStorage) {
    Remove-PrivateEndpoint -peName $peStorageName -description "Storage Account"
}

# Remove Key Vault PE
if (-not $SkipKeyVault) {
    Remove-PrivateEndpoint -peName $peKeyVaultName -description "Key Vault"
}

# Remove Foundry PE
if (-not $SkipFoundry) {
    Remove-PrivateEndpoint -peName $peFoundryName -description "Azure AI Foundry"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Private Endpoints Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: Services are now accessible via public endpoints only." -ForegroundColor Yellow
Write-Host "To restore private connectivity, re-run deploy-private-endpoints.ps1" -ForegroundColor Yellow