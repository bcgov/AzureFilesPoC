<#
    Deploy Storage Account with Network ACLs
    
    For SAS token generation after deployment:
    az storage container generate-sas --account-name stagpssgazurepocdev01 `
      --name <container-name> --permissions acdlrw `
      --expiry 2025-12-31T23:59:59Z --https-only
#>

# Load environment variables from azure.env
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $line = $line.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim() -replace '^"(.*)"$', '$1'
                [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            }
        }
    }
    Write-Host "Loaded environment variables from azure.env" -ForegroundColor Green
} else {
    Write-Error "azure.env file not found at $envFile"
    exit 1
}

# Set variables
$resourceGroup = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_REGION
$storageAccountName = $env:STORAGE_ACCOUNT

Write-Host "`n=== Storage Account Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Location: $location"
Write-Host "Storage Account: $storageAccountName"

# Check if storage account already exists
Write-Host "`nChecking if storage account exists..." -ForegroundColor Yellow
$existing = az storage account show --name $storageAccountName --resource-group $resourceGroup --query "name" -o tsv 2>$null

if ($existing -eq $storageAccountName) {
    Write-Host "Storage account '$storageAccountName' already exists. Skipping creation." -ForegroundColor Green
    exit 0
}

# Deploy
$bicepPath = Join-Path $PSScriptRoot "..\..\bicep\storage-stagpssgazurepocdev01.bicep"
$deploymentName = "storage-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "`nDeploying storage account (this may take 2-3 minutes)..." -ForegroundColor Yellow
Write-Host "Command: az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters location=$location`n" -ForegroundColor Gray

$result = az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters location=$location

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nStorage account '$storageAccountName' created successfully!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Verify network ACLs allow your IP range (142.28-32.x.x configured)"
    Write-Host "2. Create blob containers as needed"
    Write-Host "3. Generate SAS tokens for programmatic access"
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}
