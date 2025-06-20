# Function to resolve script location and set correct paths
function Resolve-ScriptPath {
    $script:ScriptDir = $PSScriptRoot
    if (-not $script:ScriptDir) {
        $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    
    # Navigate to project root (up from scripts/windows/RegisterApplicationInAzureAndOIDC/OneTimeActivities)
    $script:ProjectRoot = (Get-Item $script:ScriptDir).Parent.Parent.Parent.Parent.FullName
    
    Write-Host "Script running from: $script:ScriptDir"
    Write-Host "Project root: $script:ProjectRoot"
}

# Call path resolution function
Resolve-ScriptPath

# Initialize variables
$Script:AppName = "ag-pssg-azure-files-poc-ServicePrincipal"
$Script:EnvPath = Join-Path $script:ProjectRoot ".env"
$Script:CredsFile = Join-Path $Script:EnvPath "azure-credentials.json"
$Script:TemplateFile = Join-Path $Script:EnvPath "azure-credentials.template.json"
$Script:GithubOrg = "bcgov"
$Script:GithubRepo = "AzureFilesPoC"

# Check if running in Windows PowerShell
if (-not $PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT") {
    $isWindows = $true
} else {
    Write-Error "This script must be run in Windows PowerShell"
    exit 1
}

# Function to verify prerequisites
function Test-Prerequisites {
    # Check Azure CLI
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI is required but not installed. Download from: https://aka.ms/installazurecliwindows"
        exit 1
    }


# Verify prerequisites
Test-Prerequisites


# Function to initialize credentials file from template
function Initialize-CredentialsFile {
    # Ensure .env directory exists
    if (-not (Test-Path $Script:EnvPath)) {
        New-Item -ItemType Directory -Path $Script:EnvPath -Force | Out-Null
    }

    # Check if template exists
    if (-not (Test-Path $Script:TemplateFile)) {
        Write-Error "Template file not found at $($Script:TemplateFile)"
        exit 1
    }

    # Copy template to credentials file if it doesn't exist
    if (-not (Test-Path $Script:CredsFile)) {
        Write-Host "Initializing credentials file from template..."
        Copy-Item -Path $Script:TemplateFile -Destination $Script:CredsFile

        # Read the JSON
        $creds = Get-Content $Script:CredsFile | ConvertFrom-Json

        # Update GitHub values and ensure clean structure
        $creds.github.org = $Script:GithubOrg
        $creds.github.repo = $Script:GithubRepo

        # Ensure subscription and role assignments structure
        if (-not $creds.azure.subscription) {
            $creds.azure | Add-Member -NotePropertyName 'subscription' -NotePropertyValue @{
                id = ""
                roleAssignments = @()
            }
        } else {
            $creds.azure.subscription.roleAssignments = @()
        }

        # Save updated content
        $creds | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
    }

    # Verify the file is valid JSON
    try {
        $null = Get-Content $Script:CredsFile | ConvertFrom-Json
    }
    catch {
        Write-Error "Invalid JSON in credentials file"
        exit 1
    }
}

# Function to update credentials file
function Update-CredentialsFile {
    param (
        [string]$Field,
        [string]$Value
    )

    # Ensure .env directory exists
    if (-not (Test-Path $Script:EnvPath)) {
        New-Item -ItemType Directory -Path $Script:EnvPath -Force | Out-Null
    }

    # Create initial JSON structure if file doesn't exist
    if (-not (Test-Path $Script:CredsFile)) {
        $initialJson = @{
            metadata = @{
                dateCreated = ""
            }
            azure = @{
                ad = @{
                    tenantId = ""
                    application = @{
                        name = ""
                        clientId = ""
                        servicePrincipalObjectId = ""
                        oidcConfiguration = @{
                            federatedCredentials = @()
                            configuredOn = ""
                        }
                    }
                }
                subscription = @{
                    id = ""
                    roleAssignments = @()
                }
            }
            github = @{
                org = $Script:GithubOrg
                repo = $Script:GithubRepo
                secrets = @{
                    configured = @()
                    configuredOn = ""
                    available = @("AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID")
                }
            }
        }
        $initialJson | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
    }

    # Read current content
    $credentials = Get-Content $Script:CredsFile | ConvertFrom-Json

    # Update the specified field
    switch ($Field) {
        "metadata.dateCreated" { $credentials.metadata.dateCreated = $Value }
        "azure.ad.tenantId" { $credentials.azure.ad.tenantId = $Value }
        "azure.ad.application.name" { $credentials.azure.ad.application.name = $Value }
        "azure.ad.application.clientId" { $credentials.azure.ad.application.clientId = $Value }
        "azure.ad.application.servicePrincipalObjectId" { $credentials.azure.ad.application.servicePrincipalObjectId = $Value }
        "azure.subscription.id" { $credentials.azure.subscription.id = $Value }
    }

    # Save updated content
    $credentials | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
    Write-Host "Updated $Field in credentials file"
}

# Login to Azure
Write-Host "Logging in to Azure..."
az login

# Initialize credentials file from template
Initialize-CredentialsFile

# Get or create app registration
Write-Host "Checking for existing app registration..."
$existingApp = $(az ad app list --display-name $appName --query '[0].appId' -o tsv)

if ($existingApp) {
    Write-Host "Found existing app registration with ID: $existingApp"
    $appId = $existingApp
} else {
    Write-Host "Creating new app registration..."
    $newApp = az ad app create --display-name $appName --identifier-uris "https://$appName" --query "appId" -o tsv
    Write-Host "Created new app registration with ID: $newApp"
    $appId = $newApp
}

# Update credentials file with app registration details
$currentTime = Get-Date -Format "yyyy-MM-dd HH:mm"
Update-CredentialsFile -Field "metadata.dateCreated" -Value $currentTime
Update-CredentialsFile -Field "azure.ad.application.name" -Value $Script:AppName
Update-CredentialsFile -Field "azure.ad.application.clientId" -Value $appId
Update-CredentialsFile -Field "azure.ad.tenantId" -Value $tenantId
Update-CredentialsFile -Field "azure.subscription.id" -Value $subscriptionId
Update-CredentialsFile -Field "azure.ad.application.servicePrincipalObjectId" -Value $spId

Write-Host "Credentials file has been updated with all registration details"

# Display results
Write-Host "`nRegistration Results:"
Write-Host "- Client ID: $appId"
Write-Host "- Tenant ID: $tenantId"
Write-Host "- Subscription ID: $subscriptionId"
Write-Host "- Service Principal Object ID: $spId"

Write-Host "`nNext Steps:"
Write-Host "1. Verify these values match your existing app registration"
Write-Host "2. Run step2_grant_permissions.ps1 to verify/set up role assignments"
Write-Host "3. Run step3_configure_oidc.ps1 to set up GitHub Actions authentication"
