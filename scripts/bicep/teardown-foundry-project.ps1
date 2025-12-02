# Teardown Azure AI Foundry Project
# This script removes the Foundry Project workspace

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
$projectName = $env:FOUNDRY_PROJECT

Write-Host "`n=== Teardown Azure AI Foundry Project ===" -ForegroundColor Cyan
Write-Host "Project: $projectName" -ForegroundColor Yellow

# Check if Project exists
$projectExists = az ml workspace show `
    --name $projectName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "name" -o tsv 2>$null

if (-not $projectExists) {
    Write-Host "Foundry Project '$projectName' not found. Nothing to delete." -ForegroundColor Yellow
    exit 0
}

# Confirm deletion
if (-not $Force) {
    Write-Host "`nWARNING: This will delete the Foundry Project and all its deployments!" -ForegroundColor Red
    $confirm = Read-Host "Type 'yes' to proceed"
    if ($confirm -ne 'yes') {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Delete Project
Write-Host "`nDeleting Foundry Project '$projectName'..." -ForegroundColor Cyan
az ml workspace delete `
    --name $projectName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --yes `
    --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "Foundry Project deletion initiated (running in background)." -ForegroundColor Green
} else {
    Write-Host "Failed to delete Foundry Project." -ForegroundColor Red
    exit 1
}
