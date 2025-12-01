<#
    Deploy Storage Account with Network ACLs
    
    IMPORTANT: To upload/download files, you must add your IP to the allowlist:
    
    1. Edit bicep/storage-stagpssgazurepocdev01.bicep
    2. Add your IP/CIDR to networkAcls.ipRules array:
       {
         value: 'YOUR.IP.ADDRESS.HERE'
         action: 'Allow'
       }
    3. Redeploy this script
    
    For SAS token generation after deployment:
    az storage container generate-sas --account-name stagpssgazurepocdev01 \
      --name <container-name> --permissions acdlrw \
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
    Write-Host "✓ Loaded environment variables from azure.env" -ForegroundColor Green
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
Write-Host "Template: bicep\storage-stagpssgazurepocdev01.bicep`n"

# Check if storage account already exists
Write-Host "Checking if storage account '$storageAccountName' exists..." -ForegroundColor Yellow
$existing = az storage account show --name $storageAccountName --resource-group $resourceGroup --query "name" -o tsv 2>$null

if ($existing -eq $storageAccountName) {
    Write-Host "✓ Storage account '$storageAccountName' already exists. Skipping creation." -ForegroundColor Green
    exit 0
}

# Build the deployment command
$bicepPath = Join-Path $PSScriptRoot "..\..\bicep\storage-stagpssgazurepocdev01.bicep"
$deploymentName = "storage-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "`nDeploying storage account..." -ForegroundColor Yellow
Write-Host "Command: az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters location=$location" -ForegroundColor Gray
Write-Host "This may take 2-3 minutes...`n" -ForegroundColor Yellow

$result = az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters location=$location

Write-Host "`nDeployment command completed with exit code: $LASTEXITCODE" -ForegroundColor Gray

if ($LASTEXITCODE -eq 0) {
    $resultJson = $result | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($resultJson -and $resultJson.properties -and $resultJson.properties.error) {
        Write-Error "ARM deployment failed: $($resultJson.properties.error.message)"
        $result | Write-Host
        exit 1
    }
    Write-Host "`n✓ Storage account '$storageAccountName' created successfully!" -ForegroundColor Green
    
    # Show storage account details
    Write-Host "`nRetrieving storage account details..." -ForegroundColor Yellow
    az storage account show --name $storageAccountName --resource-group $resourceGroup --query '{name:name,location:location,sku:sku.name,accessTier:accessTier,httpsOnly:supportsHttpsTrafficOnly,publicAccess:publicNetworkAccess}' -o table
    
    Write-Host "`n✓ Deployment complete!" -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Verify network ACLs allow your IP range (142.28-32.x.x configured)"
    Write-Host "2. Create blob containers as needed"
    Write-Host "3. Generate SAS tokens for programmatic access"
} else {
    Write-Host "`nDeployment failed. Output:" -ForegroundColor Red
    $result | Write-Host
    Write-Error "Failed to create storage account '$storageAccountName'"
    exit 1
}

