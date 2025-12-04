# Filename: scripts/bicep/teardown-openai.ps1
# Teardown Azure OpenAI resource and its private endpoint
# Run this script to remove the Azure OpenAI resource when no longer needed

# Load environment variables from azure.env
$envFile = "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*$' -or $_ -match '^\s*#') { return }
        if ($_ -match '^\s*([^=]+)\s*=\s*(.+?)\s*(#.*)?$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($value -match '^"(.+)"$') { $value = $matches[1] }
            Set-Item -Path "env:$key" -Value $value
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$resourceGroup = $env:RG_AZURE_FILES
$openAIName = "openai-ag-pssg-azure-files"
$peName = "pe-openai-ag-pssg-azure-files"

Write-Host "
=== Azure OpenAI Teardown ===" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "OpenAI Name: $openAIName" -ForegroundColor Gray
Write-Host "Private Endpoint: $peName" -ForegroundColor Gray

az account set --subscription $subscriptionId

# Delete Private Endpoint first
Write-Host "
Deleting Private Endpoint: $peName" -ForegroundColor Yellow
az network private-endpoint delete `
    --name $peName `
    --resource-group $resourceGroup `
    --no-wait

# Delete Azure OpenAI resource
Write-Host "
Deleting Azure OpenAI resource: $openAIName" -ForegroundColor Yellow
az cognitiveservices account delete `
    --name $openAIName `
    --resource-group $resourceGroup

Write-Host "
=== Azure OpenAI Teardown Complete ===" -ForegroundColor Green
