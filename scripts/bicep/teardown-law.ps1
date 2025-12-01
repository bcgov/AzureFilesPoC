# Teardown Log Analytics Workspace
# This script removes the Log Analytics Workspace created for the AI Foundry Landing Zone

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
$lawName = $env:LAW_NAME

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Log Analytics Workspace" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "LAW Name: $lawName"
Write-Host ""

# Check if LAW exists
Write-Host "Checking if Log Analytics Workspace exists..." -ForegroundColor Yellow
$law = az monitor log-analytics workspace show `
    --workspace-name $lawName `
    --resource-group $resourceGroup `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($law)) {
    Write-Host "Log Analytics Workspace '$lawName' does not exist. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "Log Analytics Workspace found: $law" -ForegroundColor Green

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the Log Analytics Workspace and all its data." -ForegroundColor Red
Write-Host "All diagnostic logs and queries will be permanently deleted." -ForegroundColor Red
Write-Host "The workspace can be recovered within 14 days using soft-delete recovery." -ForegroundColor Yellow
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete LAW
Write-Host ""
Write-Host "Deleting Log Analytics Workspace '$lawName'..." -ForegroundColor Yellow
az monitor log-analytics workspace delete `
    --workspace-name $lawName `
    --resource-group $resourceGroup `
    --yes

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Log Analytics Workspace '$lawName' deleted successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 Note: The workspace is soft-deleted and can be recovered within 14 days." -ForegroundColor Yellow
    Write-Host "To permanently delete (purge), use:" -ForegroundColor Yellow
    Write-Host "az monitor log-analytics workspace delete --workspace-name $lawName --resource-group $resourceGroup --force true --yes" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "❌ Failed to delete Log Analytics Workspace. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
