# Teardown User-Assigned Managed Identity
# This script removes the User-Assigned Managed Identity created for the AI Foundry Landing Zone

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
$uamiName = $env:UAMI_NAME

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down User-Assigned Managed Identity" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "UAMI Name: $uamiName"
Write-Host ""

# Check if UAMI exists
Write-Host "Checking if UAMI exists..." -ForegroundColor Yellow
$uami = az identity show `
    --name $uamiName `
    --resource-group $resourceGroup `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($uami)) {
    Write-Host "UAMI '$uamiName' does not exist. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "UAMI found: $uami" -ForegroundColor Green

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the User-Assigned Managed Identity." -ForegroundColor Red
Write-Host "Any resources using this identity will lose access to resources." -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete UAMI
Write-Host ""
Write-Host "Deleting UAMI '$uamiName'..." -ForegroundColor Yellow
az identity delete `
    --name $uamiName `
    --resource-group $resourceGroup

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ UAMI '$uamiName' deleted successfully!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Failed to delete UAMI. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
