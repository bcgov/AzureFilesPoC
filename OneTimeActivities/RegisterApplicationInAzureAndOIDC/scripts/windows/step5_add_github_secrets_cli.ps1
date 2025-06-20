# Script to add GitHub secrets using the GitHub CLI
# This script automates the process outlined in Step 5 Alternative A

# Verify prerequisites
function Verify-Prerequisites {
    # Check if GitHub CLI is installed
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI is required but not installed."
        Write-Host "Install using: winget install --id GitHub.cli"
        Write-Host "Or visit: https://cli.github.com/manual/installation"
        exit 1
    }
    
    # Check if PowerShell version is sufficient
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher is required"
        exit 1
    }
    
    # Check if gh is authenticated
    try {
        $null = gh auth status
    }
    catch {
        Write-Error "GitHub CLI is not authenticated. Please login first."
        Write-Host "Run: gh auth login"
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

# Try different possible paths for the values
try {
    $clientId = if ($creds.azure.ad.application.clientId) { $creds.azure.ad.application.clientId } elseif ($creds.github.clientId) { $creds.github.clientId } else { $null }
    $tenantId = if ($creds.azure.ad.tenantId) { $creds.azure.ad.tenantId } elseif ($creds.github.tenantId) { $creds.github.tenantId } else { $null }
    $subscriptionId = if ($creds.azure.subscription.id) { $creds.azure.subscription.id } elseif ($creds.github.subscriptionId) { $creds.github.subscriptionId } else { $null }
    $githubOrg = $creds.github.org
    $githubRepo = $creds.github.repo
}
catch {
    Write-Error "Error reading values from the credentials file. JSON structure may be incorrect."
    exit 1
}

# Validate the required values
if (-not $clientId) {
    Write-Error "Client ID not found in credentials file"
    exit 1
}

if (-not $tenantId) {
    Write-Error "Tenant ID not found in credentials file"
    exit 1
}

if (-not $subscriptionId) {
    Write-Error "Subscription ID not found in credentials file"
    exit 1
}

if (-not $githubOrg -or -not $githubRepo) {
    $githubOrg = "bcgov"
    $githubRepo = "AzureFilesPoC"
    Write-Host "GitHub organization or repo not found in credentials file, using defaults:" -ForegroundColor Yellow
    Write-Host "Organization: $githubOrg" -ForegroundColor Yellow
    Write-Host "Repository: $githubRepo" -ForegroundColor Yellow
}

$repoPath = "$githubOrg/$githubRepo"

Write-Host "========== Adding GitHub Repository Secrets ==========" -ForegroundColor Green
Write-Host "Using GitHub CLI to add secrets to repository: $repoPath"

# Values being set as GitHub secrets (for verification)
Write-Host "Values being set as GitHub secrets (for verification):" -ForegroundColor Yellow
Write-Host "AZURE_CLIENT_ID: $clientId" -ForegroundColor Cyan
Write-Host "AZURE_TENANT_ID: $tenantId" -ForegroundColor Cyan
Write-Host "AZURE_SUBSCRIPTION_ID: $subscriptionId" -ForegroundColor Cyan
Write-Host ""

# Create each secret with the GitHub CLI
Write-Host "Adding AZURE_CLIENT_ID secret..." -ForegroundColor Cyan
try {
    $clientId | gh secret set AZURE_CLIENT_ID --repo $repoPath
    Write-Host "✅ Successfully added AZURE_CLIENT_ID secret" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to add AZURE_CLIENT_ID secret"
    Write-Host "Please check your GitHub CLI authentication and repository access permissions" -ForegroundColor Red
    exit 1
}

Write-Host "Adding AZURE_TENANT_ID secret..." -ForegroundColor Cyan
try {
    $tenantId | gh secret set AZURE_TENANT_ID --repo $repoPath
    Write-Host "✅ Successfully added AZURE_TENANT_ID secret" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to add AZURE_TENANT_ID secret"
    exit 1
}

Write-Host "Adding AZURE_SUBSCRIPTION_ID secret..." -ForegroundColor Cyan
try {
    $subscriptionId | gh secret set AZURE_SUBSCRIPTION_ID --repo $repoPath
    Write-Host "✅ Successfully added AZURE_SUBSCRIPTION_ID secret" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to add AZURE_SUBSCRIPTION_ID secret"
    exit 1
}

Write-Host ""
Write-Host "🎉 All GitHub secrets have been successfully added!" -ForegroundColor Green
Write-Host ""

# Update secrets configuration in JSON file
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$credsContent = Get-Content $credsFile | ConvertFrom-Json

# Make sure the secrets section exists
if (-not $credsContent.github.secrets) {
    $credsContent.github.secrets = @{}
}

# Update the secrets section
$credsContent.github.secrets.available = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
$credsContent.github.secrets.secretsAddedCLI = $true
$credsContent.github.secrets.secretsAddedCLIOn = $timestamp

# Save the updated JSON
$credsContent | ConvertTo-Json -Depth 10 | Set-Content $credsFile

Write-Host "✅ Secret status updated in credentials file" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify the secrets in GitHub by visiting:" -ForegroundColor Yellow
Write-Host "   https://github.com/$repoPath/settings/secrets/actions" -ForegroundColor Cyan
Write-Host "2. Update the Progress Tracking table in README.md to mark Step 5 as complete" -ForegroundColor Yellow
Write-Host "3. Proceed to Step 6: Validate Your Setup by following the validation process" -ForegroundColor Yellow
Write-Host ""
