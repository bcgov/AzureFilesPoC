<#
    Deploy Log Analytics Workspace (LAW)
    
    Purpose:
    - Centralized logging and diagnostics for all Azure resources
    - Collects logs from Storage, Key Vault, VM, AI Foundry, etc.
    - Enables monitoring, alerting, and troubleshooting
    - Default 30-day retention (configurable)
    
    Post-Deployment:
    - Configure diagnostic settings for each resource to send logs to LAW
    - Set up queries and alerts in Azure Monitor
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
$lawName = $env:LAW_NAME

Write-Host "`n=== Log Analytics Workspace Deployment ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Location: $location"
Write-Host "LAW: $lawName`n"

# Check if LAW already exists
Write-Host "Checking if LAW '$lawName' exists..." -ForegroundColor Yellow
$existing = az monitor log-analytics workspace show --workspace-name $lawName --resource-group $resourceGroup --query "name" -o tsv 2>$null

if ($existing -eq $lawName) {
    Write-Host "LAW '$lawName' already exists. Skipping creation." -ForegroundColor Green
    exit 0
}

# Deploy
$bicepPath = Join-Path $PSScriptRoot "..\..\bicep\law-ag-pssg-azure-files.bicep"
$deploymentName = "law-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host "Deploying Log Analytics Workspace (this may take 1-2 minutes)..." -ForegroundColor Yellow
Write-Host "Command: az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters lawName=$lawName location=$location`n" -ForegroundColor Gray

$result = az deployment group create --resource-group $resourceGroup --name $deploymentName --template-file $bicepPath --parameters lawName=$lawName location=$location

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nLog Analytics Workspace '$lawName' created successfully!" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Configure diagnostic settings for resources to send logs to LAW:"
    Write-Host "   - Storage Account"
    Write-Host "   - Key Vault"
    Write-Host "   - Virtual Machine"
    Write-Host "   - AI Foundry"
    Write-Host "2. Set up queries and alerts in Azure Monitor"
    Write-Host "3. Access logs via Azure Portal > Monitor > Logs"
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    $result | Write-Host
    exit 1
}


