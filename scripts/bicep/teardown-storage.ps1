# Teardown Storage Account
# This script removes the Storage Account created for the AI Foundry Landing Zone

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
$resourceGroup = $env:RG_AZURE_FILES
$storageAccount = $env:STORAGE_ACCOUNT

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Storage Account" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Storage Account: $storageAccount"
Write-Host ""

# Check if Storage Account exists
Write-Host "Checking if Storage Account exists..." -ForegroundColor Yellow
$storage = az storage account show `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($storage)) {
    Write-Host "Storage Account '$storageAccount' does not exist. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "Storage Account found: $storage" -ForegroundColor Green

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the Storage Account and ALL its data." -ForegroundColor Red
Write-Host "All blobs, files, tables, and queues will be permanently deleted." -ForegroundColor Red
Write-Host "This action cannot be undone." -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete Storage Account
Write-Host ""
Write-Host "Deleting Storage Account '$storageAccount'..." -ForegroundColor Yellow
az storage account delete `
    --name $storageAccount `
    --resource-group $resourceGroup `
    --yes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Storage Account '$storageAccount' deleted successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Failed to delete Storage Account. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
