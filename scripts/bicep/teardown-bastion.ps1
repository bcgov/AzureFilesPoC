# Filename: scripts/bicep/teardown-bastion.ps1
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
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

# Variables from environment
$rgName = $env:RG_AZURE_FILES
$bastionName = $env:BASTION_NAME
$publicIpName = $env:BASTION_PIP

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Azure Bastion" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: `"$rgName`"" -ForegroundColor White
Write-Host "Bastion Name: `"$bastionName`"" -ForegroundColor White
Write-Host ""

# Check if Bastion exists
Write-Host "Checking if Bastion exists..." -ForegroundColor Yellow
az network bastion show --name $bastionName --resource-group $rgName 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "✅ Bastion '$bastionName' does not exist. Nothing to delete." -ForegroundColor Green
    exit 0
}

Write-Host "Bastion found: $bastionName" -ForegroundColor Yellow
Write-Host ""

# Get Public IP details
Write-Host "Checking for associated Public IP..." -ForegroundColor Yellow
az network public-ip show --name $publicIpName --resource-group $rgName 2>$null | Out-Null
$publicIpExists = ($LASTEXITCODE -eq 0)
if ($publicIpExists) {
    Write-Host "Found Public IP: $publicIpName" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "⚠️  WARNING: This will delete the following resources:" -ForegroundColor Yellow
Write-Host "  - Bastion Host: `"$bastionName`"" -ForegroundColor White
if ($LASTEXITCODE -eq 0) {
    Write-Host "  - Public IP: `"$publicIpName`"" -ForegroundColor White
}
Write-Host ""
Write-Host "This action cannot be undone." -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "❌ Teardown cancelled by user." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Deleting Bastion Host '$bastionName'..." -ForegroundColor Yellow
az network bastion delete --name $bastionName --resource-group $rgName --yes

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Bastion deleted successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to delete Bastion. Check error messages above." -ForegroundColor Red
    exit 1
}

# Delete Public IP if it exists
if ($publicIpExists) {
    Write-Host ""
    Write-Host "Deleting Public IP '$publicIpName'..." -ForegroundColor Yellow
    az network public-ip delete --name $publicIpName --resource-group $rgName
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Public IP deleted successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: Failed to delete Public IP. It may have been auto-deleted with Bastion." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Teardown Complete" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Bastion '$bastionName' and associated resources removed!" -ForegroundColor Green
