
# Deploy Azure AI Foundry Hub Workspace
# This script deploys an Azure Machine Learning workspace with kind='Hub' (AI Foundry)
# Documentation: https://learn.microsoft.com/azure/ai-studio/how-to/create-azure-ai-resource
#
# Parameters:
#   -UseKeyVault: Include Key Vault in deployment (default: false, Foundry can auto-create if not provided)
#   -UseUAMI: Include User-Assigned Managed Identity (default: false, uses system identity if not provided)
#
# Examples:
#   .\deploy-foundry.ps1                           # Minimal deployment with Storage only
#   .\deploy-foundry.ps1 -UseKeyVault              # Include Key Vault
#   .\deploy-foundry.ps1 -UseUAMI                  # Include UAMI
#   .\deploy-foundry.ps1 -UseKeyVault -UseUAMI     # Full deployment with all resources
#
# Confirm hub install succeeded with:
# az resource list --resource-group rg-ag-pssg-azure-files-azure-foundry `
#   --query "[?type=='Microsoft.MachineLearningServices/workspaces' && kind=='Hub'].{Name:name,Kind:kind,Location:location}" -o table



param(
    [switch]$UseKeyVault = $false,
    [switch]$UseUAMI = $false
)

function Ensure-AzCli {
    $acct = az account show -o json 2>$null | ConvertFrom-Json
    if (-not $acct) {
        Write-Host "You are not logged in. Running 'az login'..." -ForegroundColor Yellow
        az login | Out-Null
    }
}

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
$subscriptionId      = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup       = $env:RG_AZURE_FILES
$location            = $env:TARGET_AZURE_FOUNDRY_REGION  # e.g., canadaeast
$foundryName         = $env:FOUNDRY_NAME
$storageAccountName  = $env:STORAGE_ACCOUNT
$keyVaultName        = $env:KEYVAULT_NAME   # <-- fixed (was KEY_VAULT)
$uamiName            = $env:UAMI_NAME
$lawName             = $env:LAW_NAME

# Validate required variables
if (-not $subscriptionId -or -not $resourceGroup -or -not $location -or -not $foundryName) {
    Write-Host "Error: Missing required environment variables (AZURE_SUBSCRIPTION_ID, RG_AZURE_FILES, TARGET_AZURE_FOUNDRY_REGION, FOUNDRY_NAME)" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Azure AI Foundry Hub Workspace Deployment ===" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Location: $location (Foundry region with LLM availability)" -ForegroundColor Gray
Write-Host "Foundry Hub Name: $foundryName" -ForegroundColor Gray
Write-Host "Use Key Vault: $UseKeyVault $(if (-not $UseKeyVault) { '(Foundry may auto-create)' })" -ForegroundColor Gray
Write-Host "Use UAMI: $UseUAMI $(if (-not $UseUAMI) { '(Foundry will use system identity)' })" -ForegroundColor Gray

# Ensure CLI and subscription context
Ensure-AzCli
az account set --subscription $subscriptionId

# Skip existence check - az ml extension not working reliably
Write-Host "`nSkipping existence check (az ml extension issues)..." -ForegroundColor Yellow
Write-Host "Proceeding with deployment - Bicep will handle idempotency" -ForegroundColor Cyan

# Get resource IDs for dependencies
Write-Host "`nRetrieving resource IDs for dependencies..." -ForegroundColor Cyan

$storageId = az storage account show `
    --name $storageAccountName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "id" -o tsv

if (-not $storageId) {
    Write-Host "Error: Storage Account '$storageAccountName' not found" -ForegroundColor Red
    exit 1
}
Write-Host "Storage Account ID: $storageId" -ForegroundColor Gray

# Get Key Vault ID if requested
$keyVaultId = ""
if ($UseKeyVault) {
    $keyVaultId = az keyvault show `
        --name $keyVaultName `
        --resource-group $resourceGroup `
        --subscription $subscriptionId `
        --query "id" -o tsv

    if (-not $keyVaultId) {
        Write-Host "Error: Key Vault '$keyVaultName' not found (required when -UseKeyVault specified)" -ForegroundColor Red
        exit 1
    }
    Write-Host "Key Vault ID: $keyVaultId" -ForegroundColor Gray
} else {
    Write-Host "Key Vault: Not used - Foundry may auto-create a workspace Key Vault" -ForegroundColor Yellow
}

# Get UAMI ID if requested
$uamiId = ""
$uamiPrincipalId = ""
if ($UseUAMI) {
    $identityInfo = az identity show `
        --name $uamiName `
        --resource-group $resourceGroup `
        --subscription $subscriptionId `
        -o json | ConvertFrom-Json

    $uamiId = $identityInfo.id
    $uamiPrincipalId = $identityInfo.principalId

    if (-not $uamiId) {
        Write-Host "Error: User-Assigned Managed Identity '$uamiName' not found (required when -UseUAMI specified)" -ForegroundColor Red
        exit 1
    }

    Write-Host "UAMI ID: $uamiId" -ForegroundColor Gray
    Write-Host "UAMI Principal ID: $uamiPrincipalId" -ForegroundColor Gray
} else {
    Write-Host "UAMI: Not used - Foundry will use system-assigned identity" -ForegroundColor Yellow
}

# Optional: Application Insights (not LAW - Foundry expects App Insights)
# For now, skip Application Insights - Foundry will work without it
$appInsightsId = ""
Write-Host "Application Insights: Not configured (optional)" -ForegroundColor Yellow

# Build Bicep template path
$bicepTemplate = "..\..\bicep\foundry-ag-pssg-azure-files.bicep"

if (-not (Test-Path $bicepTemplate)) {
    Write-Host "Error: Bicep template not found at $bicepTemplate" -ForegroundColor Red
    exit 1
}

# Deploy Bicep template
Write-Host "`nDeploying Azure AI Foundry Hub Workspace..." -ForegroundColor Cyan
Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow

$deploymentName = "deploy-foundry-hub-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$deploymentArgs = @(
    "deployment", "group", "create",
    "--subscription", $subscriptionId,
    "--resource-group", $resourceGroup,
    "--name", $deploymentName,
    "--template-file", $bicepTemplate,
    "--parameters", "foundryName=$foundryName",
    "--parameters", "location=$location",
    "--parameters", "storageAccountId=$storageId"
)

# Add optional Key Vault parameter
if ($UseKeyVault -and $keyVaultId) {
    $deploymentArgs += @("--parameters", "keyVaultId=$keyVaultId")
}

# Add optional UAMI parameter
if ($UseUAMI -and $uamiId) {
    $deploymentArgs += @("--parameters", "uamiId=$uamiId")
}

# Add optional Application Insights parameter
# Option A: Let Foundry auto-create Application Insights (simplest)
# Removed: No longer passing applicationInsightsId - Foundry will auto-create if needed

# Run deployment (FIXED redirection)
$result = & az @deploymentArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}

Write-Host "`nDeployment succeeded!" -ForegroundColor Green

# Retrieve and display deployment outputs
$outputsJson = az deployment group show `
    --subscription $subscriptionId `
    --resource-group $resourceGroup `
    --name $deploymentName `
    --query "properties.outputs" -o json

$outputs = $null
if ($outputsJson) { $outputs = $outputsJson | ConvertFrom-Json }

Write-Host "`n=== Azure AI Foundry Hub Workspace Deployed ===" -ForegroundColor Green
Write-Host "Name: $(if ($outputs -and $outputs.foundryName) { $outputs.foundryName.value } else { $foundryName })"
Write-Host "ID: $(if ($outputs -and $outputs.foundryId) { $outputs.foundryId.value } else { 'N/A' })"
Write-Host "Location: $location"
Write-Host "Discovery URL: $(if ($outputs -and $outputs.foundryDiscoveryUrl) { $outputs.foundryDiscoveryUrl.value } else { 'N/A' })"

# Optional: Show hub details only if ML extension is available
$mlExt = az extension show -n ml -o json 2>$null | ConvertFrom-Json
if ($mlExt) {
    $hubDetails = az ml workspace show `
        --name $foundryName `
        --resource-group $resourceGroup `
        --subscription $subscriptionId `
        -o json | ConvertFrom-Json

    Write-Host "`n=== Foundry Hub Configuration ===" -ForegroundColor Cyan
    Write-Host "Kind: $($hubDetails.kind)"
    Write-Host "Workspace ID: $($hubDetails.workspaceId)"
} else {
    Write-Host "`nML extension not installed; skipping 'az ml workspace show' details." -ForegroundColor Yellow
}

Write-Host "Storage Account: $storageAccountName"
Write-Host "Key Vault: $(if ($UseKeyVault) { $keyVaultName } else { 'Auto-created by Foundry (workspace KV)' })"
Write-Host "Managed Identity: $(if ($UseUAMI) { "$uamiName (User-Assigned)" } else { 'System-Assigned' })"
Write-Host "Log Analytics: $(if ($lawId) { $lawName } else { 'Not configured' })"

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Deploy Foundry Project: .\scripts\bicep\deploy-foundry-project.ps1"
Write-Host "2. (Optional) Create Private Endpoints for AI Foundry/Workspace"
Write-Host "3. (Optional) Assign RBAC roles to UAMI (e.g., Cognitive Services OpenAI User)"
Write-Host "`nAzure Portal URL:"
if ($outputs -and $outputs.foundryId) {
    Write-Host "https://portal.azure.com/#@/resource$($outputs.foundryId.value)" -ForegroundColor Gray
} else {
    Write-Host "(Check Azure Portal for foundry-ag-pssg-azure-files)" -ForegroundColor Gray
}
