# Deploy Azure AI Foundry Project
# This script deploys a Project workspace under the Foundry Hub
# Documentation: https://learn.microsoft.com/azure/ai-studio/how-to/create-projects

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
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_FOUNDRY_REGION  # Must match Hub location
$foundryName = $env:FOUNDRY_NAME
$projectName = $env:FOUNDRY_PROJECT

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

# Check if Project already exists
Write-Host "`nChecking if Foundry Project already exists..." -ForegroundColor Cyan
$existingProject = az ml workspace show `
    --name $projectName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "name" -o tsv 2>$null

if ($existingProject -eq $projectName) {
    Write-Host "Foundry Project '$projectName' already exists. Skipping deployment." -ForegroundColor Yellow
    
    # Output existing project details
    $projectDetails = az ml workspace show `
        --name $projectName `
        --resource-group $resourceGroup `
        --subscription $subscriptionId `
        -o json | ConvertFrom-Json
    
    Write-Host "`n=== Existing Foundry Project Details ===" -ForegroundColor Green
    Write-Host "Name: $($projectDetails.name)"
    Write-Host "ID: $($projectDetails.id)"
    Write-Host "Kind: $($projectDetails.kind)"
    Write-Host "Hub Resource ID: $($projectDetails.hubResourceId)"
    
    exit 0
}

# Get Hub resource ID
Write-Host "`nRetrieving parent Hub resource ID..." -ForegroundColor Cyan
$hubId = az ml workspace show `
    --name $foundryName `
    --resource-group $resourceGroup `
    --subscription $subscriptionId `
    --query "id" -o tsv

if (-not $hubId) {
    Write-Host "Error: Foundry Hub '$foundryName' not found. Please deploy the Hub first." -ForegroundColor Red
    Write-Host "Run: .\scripts\bicep\deploy-foundry.ps1" -ForegroundColor Yellow
    exit 1
}
Write-Host "Hub ID: $hubId" -ForegroundColor Gray

# Build Bicep template path
$bicepTemplate = Join-Path $rootDir "bicep\foundry-project.bicep"

if (-not (Test-Path $bicepTemplate)) {
    Write-Host "Error: Bicep template not found at $bicepTemplate" -ForegroundColor Red
    exit 1
}

# Deploy Bicep template
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

# Retrieve and display deployment outputs
$outputs = az deployment group show `
    --subscription $subscriptionId `
    --resource-group $resourceGroup `
    --name $deploymentName `
    --query "properties.outputs" -o json | ConvertFrom-Json

Write-Host "`n=== Azure AI Foundry Project Deployed ===" -ForegroundColor Green
Write-Host "Name: $($outputs.projectName.value)"
Write-Host "ID: $($outputs.projectId.value)"
Write-Host "Location: $location"
Write-Host "Workspace ID: $($outputs.projectWorkspaceId.value)"
Write-Host "Discovery URL: $($outputs.projectDiscoveryUrl.value)"

# Get full project details
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

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Deploy Private Endpoints (Phase 5) to secure connectivity"
Write-Host "2. Deploy AI models to this project through Azure AI Studio"
Write-Host "3. Test connectivity from VM through Private Endpoint"
Write-Host "`nAzure AI Studio URL:"
Write-Host "https://ai.azure.com/" -ForegroundColor Gray
Write-Host "`nAzure Portal URL:"
Write-Host "https://portal.azure.com/#@/resource$($outputs.projectId.value)" -ForegroundColor Gray
