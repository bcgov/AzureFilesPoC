# Filename: scripts/bicep/deploy-openai.ps1
# Deploy Azure OpenAI resource with private endpoint
# This script creates an Azure OpenAI resource with public network access disabled
# and a private endpoint for secure, private connectivity from the VM
#
# IMPORTANT: Azure OpenAI is required to deploy and consume AI models via private endpoints.
# Without this resource, model deployments in Azure AI Studio will fail due to policy violations.
#
# After deployment, verify with:
# az cognitiveservices account show --name openai-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry
# az network private-endpoint list --resource-group rg-ag-pssg-azure-files-azure-foundry --query "[?contains(name, 'openai')]" -o table

param(
    [switch]$SkipPrivateEndpoint = $false
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
$location = $env:TARGET_AZURE_FOUNDRY_REGION  # canadaeast for OpenAI availability
$peLocation = $env:AZURE_LOCATION  # canadacentral for PE subnet
$subnetPeName = $env:SUBNET_PE

# OpenAI resource name
$openAIName = "openai-ag-pssg-azure-files"

# Validate required variables
if (-not $subscriptionId -or -not $resourceGroup -or -not $location) {
    Write-Host "Error: Missing required environment variables" -ForegroundColor Red
    exit 1
}

Write-Host "
=== Azure OpenAI Deployment ===" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "OpenAI Location: $location (canadaeast)" -ForegroundColor Gray
Write-Host "PE Location: $peLocation (canadacentral)" -ForegroundColor Gray
Write-Host "OpenAI Name: $openAIName" -ForegroundColor Gray
Write-Host "Skip Private Endpoint: $SkipPrivateEndpoint" -ForegroundColor Gray

# Ensure CLI and subscription context
az account set --subscription $subscriptionId

# Deploy Azure OpenAI resource
Write-Host "
=== Deploying Azure OpenAI Resource ===" -ForegroundColor Cyan

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$deploymentName = "deploy-openai-$timestamp"
$bicepTemplate = "..\..\bicep\openai-ag-pssg-azure-files.bicep"

$result = az deployment group create `
    --subscription $subscriptionId `
    --resource-group $resourceGroup `
    --name $deploymentName `
    --template-file $bicepTemplate `
    --parameters "openAIName=$openAIName" `
    --parameters "location=$location" `
    --parameters "publicNetworkAccess=Disabled" `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "
Azure OpenAI deployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}

Write-Host "Azure OpenAI resource deployed successfully!" -ForegroundColor Green

# Get OpenAI resource ID for private endpoint
$openAIId = az cognitiveservices account show `
    --name $openAIName `
    --resource-group $resourceGroup `
    --query "id" -o tsv

if (-not $openAIId) {
    Write-Host "Error: Could not retrieve OpenAI resource ID" -ForegroundColor Red
    exit 1
}

Write-Host "OpenAI Resource ID: $openAIId" -ForegroundColor Gray

# Deploy Private Endpoint for Azure OpenAI
if (-not $SkipPrivateEndpoint) {
    Write-Host "
=== Deploying Azure OpenAI Private Endpoint ===" -ForegroundColor Cyan

    # Get PE subnet ID
    $subnetId = az network vnet subnet show `
        --resource-group $env:RG_NETWORKING `
        --vnet-name $env:VNET_SPOKE `
        --name $subnetPeName `
        --query "id" -o tsv

    if (-not $subnetId) {
        Write-Host "Error: Private Endpoints subnet '$subnetPeName' not found" -ForegroundColor Red
        exit 1
    }

    $peDeploymentName = "deploy-pe-openai-$timestamp"
    $peBicepTemplate = "..\..\bicep\pe-openai.bicep"

    $peResult = az deployment group create `
        --subscription $subscriptionId `
        --resource-group $resourceGroup `
        --name $peDeploymentName `
        --template-file $peBicepTemplate `
        --parameters "peName=pe-openai-ag-pssg-azure-files" `
        --parameters "location=$peLocation" `
        --parameters "subnetId=$subnetId" `
        --parameters "openAIId=$openAIId" `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "
OpenAI Private Endpoint deployment failed!" -ForegroundColor Red
        $peResult | Write-Host
        exit 1
    }

    Write-Host "Azure OpenAI Private Endpoint deployed successfully!" -ForegroundColor Green
}

Write-Host "
=== Azure OpenAI Deployment Complete ===" -ForegroundColor Green
Write-Host "OpenAI Resource: $openAIName" -ForegroundColor Gray
Write-Host "Location: $location" -ForegroundColor Gray

# Verification
Write-Host "`n=== Verification ===" -ForegroundColor Cyan
Write-Host "To verify the OpenAI resource:"
Write-Host "az cognitiveservices account show --name $openAIName --resource-group $resourceGroup -o table" -ForegroundColor Gray

Write-Host "`nTo verify the private endpoint:"
Write-Host "az network private-endpoint list --resource-group $resourceGroup --query `"[?contains(name, 'openai')]`" -o table" -ForegroundColor Gray

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Connect the Azure OpenAI resource to your Foundry project in Azure AI Studio"
Write-Host "2. Go to your Foundry project > 'Connect resources' > Add Azure OpenAI"
Write-Host "3. Deploy models from the connected Azure OpenAI resource"
Write-Host "4. Test model consumption from your VM via private endpoints"
Write-Host "`nAzure AI Studio URL: https://ai.azure.com/" -ForegroundColor Gray
