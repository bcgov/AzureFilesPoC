# Filename: scripts/bicep/deploy-private-endpoints.ps1
# Deploy Private Endpoints for Storage, Key Vault, and Azure AI Foundry
# This script creates private endpoints to enable secure, private connectivity
# from the VM to Azure services without internet exposure
#
# Private Endpoints Created:
# 1. Storage Account (blob subresource) - canadacentral
# 2. Key Vault (vault subresource) - canadacentral
# 3. Azure AI Foundry (amlworkspace subresource) - Cross-region (canadacentral → canadaeast)
#
# VERIFICATION: After deployment, test connectivity from VM:
# 1. Connect to VM via Bastion: az network bastion ssh --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry --target-resource-id $(az vm show --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry --query id -o tsv) --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa
# 2. Test DNS resolution (should return 10.x.x.x private IPs):
#    nslookup stagpssgazurepocdev01.blob.core.windows.net
#    nslookup kv-ag-pssg-azure-files.vault.azure.net
#    nslookup canadaeast.api.azureml.ms
# 3. Test service access (should work without internet):
#    az storage blob list --account-name stagpssgazurepocdev01 --container-name test
#    az keyvault secret list --vault-name kv-ag-pssg-azure-files
#    curl -H "Authorization: Bearer $(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)" https://canadaeast.api.azureml.ms/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.MachineLearningServices/workspaces/foundry-ag-pssg-azure-files?api-version=2023-10-01
#
# After deployment, verify with:
# az network private-endpoint list --resource-group rg-ag-pssg-azure-files-azure-foundry --query "[].{Name:name, Type:type, State:properties.provisioningState}" -o table

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
$location = $env:AZURE_LOCATION  # canadacentral for PE subnet
$foundryLocation = $env:TARGET_AZURE_FOUNDRY_REGION  # canadaeast for Foundry

$storageAccountName = $env:STORAGE_ACCOUNT
$keyVaultName = $env:KEYVAULT_NAME
$foundryName = $env:FOUNDRY_NAME
$subnetPeName = $env:SUBNET_PE

# Validate required variables
if (-not $subscriptionId -or -not $resourceGroup -or -not $location -or -not $foundryLocation) {
    Write-Host "Error: Missing required environment variables" -ForegroundColor Red
    exit 1
}

Write-Host "
=== Private Endpoints Deployment ===" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "PE Location: $location (canadacentral)" -ForegroundColor Gray
Write-Host "Foundry Location: $foundryLocation (canadaeast)" -ForegroundColor Gray
Write-Host "Skip Storage: $SkipStorage" -ForegroundColor Gray
Write-Host "Skip Key Vault: $SkipKeyVault" -ForegroundColor Gray
Write-Host "Skip Foundry: $SkipFoundry" -ForegroundColor Gray

# Ensure CLI and subscription context
az account set --subscription $subscriptionId

# Get PE subnet ID
Write-Host "
Retrieving Private Endpoints subnet..." -ForegroundColor Cyan
$subnetId = az network vnet subnet show `
    --resource-group $env:RG_NETWORKING `
    --vnet-name $env:VNET_SPOKE `
    --name $subnetPeName `
    --query "id" -o tsv

if (-not $subnetId) {
    Write-Host "Error: Private Endpoints subnet '$subnetPeName' not found" -ForegroundColor Red
    exit 1
}
Write-Host "PE Subnet ID: $subnetId" -ForegroundColor Gray

# Deploy Storage Account Private Endpoint
if (-not $SkipStorage) {
    Write-Host "
=== Deploying Storage Account Private Endpoint ===" -ForegroundColor Cyan

    $storageId = az storage account show `
        --name $storageAccountName `
        --resource-group $resourceGroup `
        --query "id" -o tsv

    if (-not $storageId) {
        Write-Host "Error: Storage Account '$storageAccountName' not found" -ForegroundColor Red
        exit 1
    }

    $deploymentName = "deploy-pe-storage-20251201-164538"
    $bicepTemplate = "..\..\bicep\pe-storage.bicep"

    $result = az deployment group create `
        --subscription $subscriptionId `
        --resource-group $resourceGroup `
        --name $deploymentName `
        --template-file $bicepTemplate `
        --parameters "peName=pe-storage-ag-pssg-azure-files" `
        --parameters "location=$location" `
        --parameters "subnetId=$subnetId" `
        --parameters "storageAccountId=$storageId" `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "
Storage PE deployment failed!" -ForegroundColor Red
        $result | Write-Host
        exit 1
    }

    Write-Host "Storage Account Private Endpoint deployed successfully!" -ForegroundColor Green
}

# Deploy Key Vault Private Endpoint
if (-not $SkipKeyVault) {
    Write-Host "
=== Deploying Key Vault Private Endpoint ===" -ForegroundColor Cyan

    $keyVaultId = az keyvault show `
        --name $keyVaultName `
        --resource-group $resourceGroup `
        --query "id" -o tsv

    if (-not $keyVaultId) {
        Write-Host "Error: Key Vault '$keyVaultName' not found" -ForegroundColor Red
        exit 1
    }

    $deploymentName = "deploy-pe-keyvault-20251201-164538"
    $bicepTemplate = "..\..\bicep\pe-keyvault.bicep"

    $result = az deployment group create `
        --subscription $subscriptionId `
        --resource-group $resourceGroup `
        --name $deploymentName `
        --template-file $bicepTemplate `
        --parameters "peName=pe-keyvault-ag-pssg-azure-files" `
        --parameters "location=$location" `
        --parameters "subnetId=$subnetId" `
        --parameters "keyVaultId=$keyVaultId" `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "
Key Vault PE deployment failed!" -ForegroundColor Red
        $result | Write-Host
        exit 1
    }

    Write-Host "Key Vault Private Endpoint deployed successfully!" -ForegroundColor Green
}

# Deploy Foundry Private Endpoint (Cross-region)
if (-not $SkipFoundry) {
    Write-Host "
=== Deploying Azure AI Foundry Private Endpoint (Cross-region) ===" -ForegroundColor Cyan

    $foundryId = az resource show `
        --resource-group $resourceGroup `
        --name $foundryName `
        --resource-type "Microsoft.MachineLearningServices/workspaces" `
        --query "id" -o tsv

    if (-not $foundryId) {
        Write-Host "Error: Foundry workspace '$foundryName' not found" -ForegroundColor Red
        exit 1
    }

    $deploymentName = "deploy-pe-foundry-20251201-164538"
    $bicepTemplate = "..\..\bicep\pe-foundry.bicep"

    $result = az deployment group create `
        --subscription $subscriptionId `
        --resource-group $resourceGroup `
        --name $deploymentName `
        --template-file $bicepTemplate `
        --parameters "peName=pe-foundry-ag-pssg-azure-files" `
        --parameters "location=$location" `
        --parameters "subnetId=$subnetId" `
        --parameters "foundryId=$foundryId" `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "
Foundry PE deployment failed!" -ForegroundColor Red
        $result | Write-Host
        exit 1
    }

    Write-Host "Azure AI Foundry Private Endpoint deployed successfully!" -ForegroundColor Green
    Write-Host "Note: Cross-region PE created (canadacentral  canadaeast)" -ForegroundColor Yellow
}

Write-Host "
=== Private Endpoints Deployment Complete ===" -ForegroundColor Green
Write-Host "All private endpoints have been deployed successfully!" -ForegroundColor Green

# Verification
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
Write-Host "To verify all private endpoints were created:"
Write-Host "az network private-endpoint list --resource-group `$resourceGroup --query `"[]`".{Name:name, Type:type, State:properties.provisioningState} -o table" -ForegroundColor Gray

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Test VM connectivity to Storage/Key Vault/Foundry via private endpoints"
Write-Host "2. Deploy AI models to Foundry Project through Azure AI Studio"
Write-Host "3. Run AI consumption scripts from VM using private connectivity"
Write-Host "`nAzure AI Studio URL: https://ai.azure.com/" -ForegroundColor Gray
