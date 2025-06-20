# Script to prepare GitHub secrets from Azure credentials
# This script helps you set up the required GitHub secrets for OIDC authentication

# Verify prerequisites
function Verify-Prerequisites {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher is required"
        exit 1
    }
}

# Verify prerequisites
Verify-Prerequisites

# Get the script directory and project root
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$projectRoot = (Get-Item (Join-Path $scriptDir "../../..")).FullName

# Check if credentials file exists
$credsFile = Join-Path $projectRoot ".env/azure-credentials.json"

if (-not (Test-Path $credsFile)) {
    Write-Error "Error: Credentials file not found at $credsFile"
    Write-Error "Please run step1_register_app.ps1 first"
    exit 1
}

# Read credentials using correct JSON paths
$creds = Get-Content $credsFile | ConvertFrom-Json
$clientId = $creds.azure.application.clientId
$tenantId = $creds.azure.tenantId
$subscriptionId = $creds.azure.subscriptionId
$githubOrg = $creds.github.org
$githubRepo = $creds.github.repo

Write-Host "========== GitHub Secrets Setup Guide ==========" -ForegroundColor Green
Write-Host "These values need to be added as GitHub repository secrets."
Write-Host "Follow these steps:"
Write-Host ""
Write-Host "1. Open your browser and navigate to:" -ForegroundColor Yellow
Write-Host "   https://github.com/$githubOrg/$githubRepo/settings/secrets/actions"
Write-Host ""
Write-Host "2. Click on 'New repository secret' and add each of these secrets:" -ForegroundColor Yellow
Write-Host ""
Write-Host "AZURE_CLIENT_ID:" -ForegroundColor Cyan
Write-Host $clientId
Write-Host ""
Write-Host "AZURE_TENANT_ID:" -ForegroundColor Cyan
Write-Host $tenantId
Write-Host ""
Write-Host "AZURE_SUBSCRIPTION_ID:" -ForegroundColor Cyan
Write-Host $subscriptionId

# Update secrets configuration in JSON file
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$credsContent = Get-Content $credsFile | ConvertFrom-Json

# Create secrets section
$secretsSection = @{
    configured = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
    configuredOn = $timestamp
    available = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
}

# Update the JSON
$credsContent.github.secrets = $secretsSection
$credsContent | ConvertTo-Json -Depth 10 | Set-Content $credsFile

Write-Host ""
Write-Host "3. Secrets configuration has been recorded in $credsFile" -ForegroundColor Green
Write-Host "4. Update the Progress Tracking table in README.md to mark this step as complete" -ForegroundColor Green
Write-Host ""
Write-Host "For security, these values are never stored in the repository." -ForegroundColor Yellow
Write-Host "Remember to keep them secure and never share them." -ForegroundColor Yellow
