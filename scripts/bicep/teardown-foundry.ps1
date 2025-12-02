# Filename: scripts/bicep/teardown-foundry.ps1
# Teardown Azure AI Foundry Hub
# This script removes the Foundry Hub workspace
# NOTE: Delete all Projects first before deleting the Hub

param(
    [switch]$Force
)

# Load environment variables from azure.env
$envFile = "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*["]?([^"]*)["]?\s*$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
} else {
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RG_AZURE_FILES
$foundryName = $env:FOUNDRY_NAME
$projectName = $env:FOUNDRY_PROJECT

Write-Host "`n=== Teardown Azure AI Foundry Hub ===" -ForegroundColor Cyan
Write-Host "Hub: $foundryName" -ForegroundColor Yellow

# Check if Hub exists
$hubExists = az ml workspace show `
    --name $foundryName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "name" -o tsv 2>$null

if (-not $hubExists) {
    Write-Host "Foundry Hub '$foundryName' not found. Nothing to delete." -ForegroundColor Yellow
    exit 0
}

# Check if Project still exists
$projectExists = az ml workspace show `
    --name $projectName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "name" -o tsv 2>$null

if ($projectExists) {
    Write-Host "`nERROR: Foundry Project '$projectName' still exists!" -ForegroundColor Red
    Write-Host "Please delete the Project first: .\scripts\bicep\teardown-foundry-project.ps1" -ForegroundColor Yellow
    exit 1
}

# Confirm deletion
if (-not $Force) {
    Write-Host "`nWARNING: This will delete the Foundry Hub and all its configurations!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to proceed"
    if ($confirm -ne 'yes') {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Delete Hub
Write-Host "`nDeleting Foundry Hub '$foundryName'..." -ForegroundColor Cyan
az ml workspace delete `
    --name $foundryName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --yes `
    --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "Foundry Hub deletion initiated (running in background)." -ForegroundColor Green
    Write-Host "`nNote: Storage Account, Key Vault, and UAMI are NOT deleted." -ForegroundColor Yellow
    Write-Host "Use Phase 2 teardown scripts to remove those resources if needed." -ForegroundColor Yellow
} else {
    Write-Host "Failed to delete Foundry Hub." -ForegroundColor Red
    exit 1
}
