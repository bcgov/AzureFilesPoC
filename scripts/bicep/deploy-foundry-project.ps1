
# Deploy Azure AI Foundry Project
# This script deploys a Project workspace under the Foundry Hub
# Docs: https://learn.microsoft.com/azure/ai-studio/how-to/create-projects
#
# After project deployment, list projects:
# az resource list --resource-group rg-ag-pssg-azure-files-azure-foundry `
#   --query "[?type=='Microsoft.MachineLearningServices/workspaces' && kind=='Project'].{Name:name,Kind:kind,Location:location}" -o table


# ---------------------------
# Load environment variables
# ---------------------------
$envFile = "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*["]?([^"]*)["]?\s*$') {
            $name  = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

# ---------------------------
# Variables from environment
# ---------------------------
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup  = $env:RG_AZURE_FILES
$location       = $env:TARGET_AZURE_FOUNDRY_REGION  # Must match Hub location
$foundryName    = $env:FOUNDRY_NAME
$projectName    = $env:FOUNDRY_PROJECT

# Validate required variables
if (-not $subscriptionId -or -not $resourceGroup -or -not $location -or -not $foundryName -or -not $projectName) {
    Write-Host "Error: Missing required environment variables" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Azure AI Foundry Project Deployment ===" -ForegroundColor Cyan
Write-Host "Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Location: $location" -ForegroundColor Gray
Write-Host "Parent Hub: $foundryName" -ForegroundColor Gray
Write-Host "Project Name: $projectName" -ForegroundColor Gray

# ---------------------------
# Ensure CLI context
# ---------------------------
function Ensure-AzCli {
    $acct = az account show -o json 2>$null | ConvertFrom-Json
    if (-not $acct) {
        Write-Host "You are not logged in. Running 'az login'..." -ForegroundColor Yellow
        az login | Out-Null
    }
}
Ensure-AzCli
az account set --subscription $subscriptionId

# ---------------------------
# Get Hub resource ID (no az ml dependency)
# ---------------------------
Write-Host "`nRetrieving parent Hub resource ID..." -ForegroundColor Cyan
$hubId = az resource show `
    --resource-group $resourceGroup `
    --name $foundryName `
    --resource-type "Microsoft.MachineLearningServices/workspaces" `
    --query "id" -o tsv 2>$null

if (-not $hubId) {
    Write-Host "Error: Foundry Hub '$foundryName' not found. Please deploy the Hub first." -ForegroundColor Red
    Write-Host "Run: .\scripts\bicep\deploy-foundry.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "Hub ID: $hubId" -ForegroundColor Gray

# ---------------------------
# Resolve Bicep template path
# ---------------------------
$rootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bicepTemplate = Join-Path $rootDir "bicep\foundry-project.bicep"

# Fallback (in case of unusual layout)
if (-not (Test-Path $bicepTemplate)) {
    $bicepTemplate = "..\..\bicep\foundry-project.bicep"
}

if (-not (Test-Path $bicepTemplate)) {
    Write-Host "Error: Bicep template not found at $bicepTemplate" -ForegroundColor Red
    exit 1
}

# ---------------------------
# Deploy Bicep template
# ---------------------------
Write-Host "`nDeploying Azure AI Foundry Project..." -ForegroundColor Cyan
Write-Host "This may take 2-5 minutes..." -ForegroundColor Yellow

$deploymentName = "deploy-foundry-project-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$result = az deployment group create `
    --subscription $subscriptionId `
    --resource-group $resourceGroup `
    --name $deploymentName `
    --template-file $bicepTemplate `
    --parameters projectName=$projectName `
    --parameters location=$location `
    --parameters hubResourceId=$hubId `
    2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}

Write-Host "`nDeployment succeeded!" -ForegroundColor Green

# ---------------------------
# Retrieve deployment outputs
# ---------------------------
$outputsJson = az deployment group show `
    --subscription $subscriptionId `
    --resource-group $resourceGroup `
    --name $deploymentName `
    --query "properties.outputs" -o json

$outputs = $null
if ($outputsJson) { $outputs = $outputsJson | ConvertFrom-Json }

Write-Host "`n=== Azure AI Foundry Project Deployed ===" -ForegroundColor Green
Write-Host "Name: $(if ($outputs -and $outputs.projectName) { $outputs.projectName.value } else { $projectName })"
Write-Host "ID: $(if ($outputs -and $outputs.projectId) { $outputs.projectId.value } else { 'N/A' })"
Write-Host "Location: $location"
Write-Host "Workspace ID: $(if ($outputs -and $outputs.projectWorkspaceId) { $outputs.projectWorkspaceId.value } else { 'N/A' })"
Write-Host "Discovery URL: $(if ($outputs -and $outputs.projectDiscoveryUrl) { $outputs.projectDiscoveryUrl.value } else { 'N/A' })"

# ---------------------------
# Optional: Show project details via az ml (only if extension installed)
# ---------------------------
$mlExt = az extension show -n ml -o json 2>$null | ConvertFrom-Json
if ($mlExt) {
    $projectDetails = az ml workspace show `
        --name $projectName `
        --resource-group $resourceGroup `
        --subscription $subscriptionId `
        -o json | ConvertFrom-Json

    Write-Host "`n=== Project Configuration ===" -ForegroundColor Cyan
    Write-Host "Kind: $($projectDetails.kind)"
    Write-Host "Parent Hub: $foundryName"
    Write-Host "Hub Resource ID: $($projectDetails.hubResourceId)"
    Write-Host "Public Network Access: $($projectDetails.publicNetworkAccess)"
} else {
    Write-Host "`nML extension not installed; skipping 'az ml workspace show' details." -ForegroundColor Yellow
}

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Deploy Private Endpoints (Phase 5) to secure connectivity"
Write-Host "2. Deploy AI models to this project through Azure AI Studio"
Write-Host "3. Test connectivity from VM through Private Endpoint"
Write-Host "`nAzure AI Studio URL:"
Write-Host "https://ai.azure.com/" -ForegroundColor Gray
Write-Host "`nAzure Portal URL:"
if ($outputs -and $outputs.projectId) {
    Write-Host "https://portal.azure.com/#@/resource$($outputs.projectId.value)" -ForegroundColor Gray
} else {
    Write-Host "(Check Azure Portal for foundry-ag-pssg-azure-files-project)" -ForegroundColor Gray
}
