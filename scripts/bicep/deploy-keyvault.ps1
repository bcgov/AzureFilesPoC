# Filename: scripts/bicep/deploy-keyvault.ps1
<#
    Deploy Azure Key Vault with Network ACLs
    
    IMPORTANT: Network Access Configuration
    - Public network access DISABLED (BC Gov policy requirement)
    - Access ONLY via Private Endpoint (deploy in Phase 4)
    - Key Vault uses RBAC authorization (not access policies)
    - Soft delete enabled with 90-day retention
    - Purge protection enabled (cannot be disabled once set)
    
    Post-Deployment:
    - Assign RBAC roles for users/identities:
      az role assignment create --role "Key Vault Secrets Officer" \
        --assignee <user-or-managed-identity> \
        --scope /subscriptions/.../resourceGroups/.../providers/Microsoft.KeyVault/vaults/<vault-name>
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
$keyVaultName = $env:KEYVAULT_NAME

Write-Host "`n=== Key Vault Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Location: $location"
Write-Host "Key Vault: $keyVaultName`n"

# Check if Key Vault already exists
Write-Host "Checking if Key Vault '$keyVaultName' exists..." -ForegroundColor Yellow
$existing = az keyvault show --name $keyVaultName --resource-group $resourceGroup --query "name" -o tsv 2>$null

if ($existing -eq $keyVaultName) {
    Write-Host "Key Vault '$keyVaultName' already exists. Skipping creation." -ForegroundColor Green
    exit 0
}

# Deploy
$bicepPath = Join-Path $PSScriptRoot "..\..\bicep\keyvault-ag-pssg-azure-files.bicep"
$deploymentName = "keyvault-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Deploying Key Vault (this may take 1-2 minutes)..." -ForegroundColor Yellow
Write-Host "Command: az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters keyVaultName=$keyVaultName location=$location`n" -ForegroundColor Gray

$result = az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters keyVaultName=$keyVaultName location=$location

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nKey Vault '$keyVaultName' created successfully!" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Assign RBAC roles for users/managed identities to access secrets"
    Write-Host "2. Verify network ACLs allow your VPN IP range (142.28-32.x.x configured)"
    Write-Host "3. Store secrets, connection strings, and API keys"
    Write-Host "`nExample RBAC assignment:"
    Write-Host "az role assignment create --role 'Key Vault Secrets Officer' --assignee <user-or-identity> --scope /subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$resourceGroup/providers/Microsoft.KeyVault/vaults/$keyVaultName" -ForegroundColor Gray
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}


