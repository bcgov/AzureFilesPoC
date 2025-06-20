# Script to configure OpenID Connect (OIDC) for GitHub Actions
# Requires: Azure CLI, PowerShell 5.1 or higher

# Initialize variables
$Script:AppName = "ag-pssg-azure-files-poc-ServicePrincipal"
$Script:ProjectRoot = $null
$Script:ScriptDir = $null
$Script:EnvPath = $null
$Script:CredsFile = $null
$Script:GithubOrg = "bcgov"
$Script:GithubRepo = "AzureFilesPoC"
$Script:Environments = @(
    @{
        Name = "github-federated-identity-main-branch"
        Subject = "repo:$Script:GithubOrg/$Script:GithubRepo`:ref:refs/heads/main"
    },
    @{
        Name = "github-federated-identity-pull-requests"
        Subject = "repo:$Script:GithubOrg/$Script:GithubRepo`:pull_request"
    },
    @{
        Name = "github-federated-identity-dev-environment"
        Subject = "repo:$Script:GithubOrg/$Script:GithubRepo`:environment:dev"
    }
)

# Function to resolve script location and set correct paths
function Resolve-ScriptPath {
    $script:ScriptDir = $PSScriptRoot
    if (-not $script:ScriptDir) {
        $script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
    
    # Navigate to project root (up from scripts/windows/RegisterApplicationInAzureAndOIDC/OneTimeActivities)
    $script:ProjectRoot = (Get-Item $script:ScriptDir).Parent.Parent.Parent.Parent.FullName
    $script:EnvPath = Join-Path $script:ProjectRoot ".env"
    $script:CredsFile = Join-Path $script:EnvPath "azure-credentials.json"
    
    Write-Host "Script running from: $script:ScriptDir"
    Write-Host "Project root: $script:ProjectRoot"
}

# Function to verify prerequisites
function Verify-Prerequisites {
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.1 or higher is required"
        exit 1
    }

    # Check Azure CLI
    try {
        $null = Get-Command az
    }
    catch {
        Write-Error "Azure CLI is required but not installed. Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-windows"
        exit 1
    }
}

# Function to check if already logged in
function Check-LoginStatus {
    Write-Host "Checking Azure CLI login status..."
    try {
        $result = az account show 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Already logged in to Azure CLI"
            return $true
        }
    }
    catch {}
    
    Write-Host "Not logged in to Azure CLI"
    return $false
}

# Function to ensure logged in with correct permissions
function Ensure-LoggedIn {
    if (-not (Check-LoginStatus)) {
        Write-Error "Please log in to Azure CLI first using 'az login'"
        exit 1
    }

    # Check subscription selection
    $currentSub = Execute-AzCommand "az account show --query name -o tsv"
    if (-not $currentSub) {
        Write-Error "Failed to get current subscription"
        exit 1
    }

    # Get subscription from credentials file
    $creds = Get-Content $Script:CredsFile | ConvertFrom-Json
    if ($creds.azure.subscriptionId) {
        Write-Host "Verifying subscription..."
        $subDetails = Execute-AzCommand "az account show --subscription $($creds.azure.subscriptionId) --query name -o tsv"
        if (-not $subDetails) {
            Write-Host "Warning: Could not find subscription from credentials file"
            Write-Host "Available subscriptions:"
            Execute-AzCommand "az account list --query '[].{name:name, id:id}' -o table"
            Write-Host "`nPlease select the correct subscription using: az account set --subscription '<name or id>'"
            Write-Host "Press Enter to continue with current subscription, or Ctrl+C to exit"
            Read-Host
        }
        elseif ($currentSub -ne $subDetails) {
            Write-Host "Warning: Current subscription ($currentSub) does not match configuration ($subDetails)"
            Write-Host "Available subscriptions:"
            Execute-AzCommand "az account list --query '[].{name:name, id:id}' -o table"
            Write-Host "`nPlease select the correct subscription using: az account set --subscription '<name or id>'"
            Write-Host "Press Enter to continue with current subscription, or Ctrl+C to exit"
            Read-Host
        }
    }

    # Verify Graph API permissions quietly
    try {
        $null = az account get-access-token --resource-type ms-graph 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Refreshing Microsoft Graph permissions..."
            az login --scope "https://graph.microsoft.com//.default"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to get required Microsoft Graph permissions. Please try again."
                exit 1
            }
        }
    }
    catch {
        Write-Error "Failed to verify Graph API permissions: $_"
        exit 1
    }

    # Display current context
    Write-Host "`nCurrent Azure context:"
    az account show -o table
    Write-Host "`nPress Enter to continue with this context, or Ctrl+C to exit and run 'az login' with different credentials"
    Read-Host
}

# Function to handle Azure CLI errors
function Handle-AzureError {
    param (
        [string]$ErrorMessage
    )
    
    if ($ErrorMessage -match "AADSTS70043" -or $ErrorMessage -match "expired") {
        Write-Host "Token expired or permission issue detected. Attempting to refresh login..."
        az account clear
        az login --scope "https://graph.microsoft.com//.default"
        return $true
    }
    elseif ($ErrorMessage -match "authentication needed") {
        Write-Host "Authentication needed. Please login again..."
        az login --scope "https://graph.microsoft.com//.default"
        return $true
    }
    return $false
}

# Function to execute Azure CLI command with retry
function Execute-AzCommand {
    param (
        [string]$Command
    )
    
    $maxRetries = 3
    $retry = 0
    
    while ($retry -lt $maxRetries) {
        try {
            $result = Invoke-Expression "& $Command" 2>&1
            if ($LASTEXITCODE -eq 0) {
                return $result
            }
            else {
                $errorMsg = $result | Out-String
                if (Handle-AzureError -ErrorMessage $errorMsg) {
                    $retry++
                    Write-Host "Retrying command... (Attempt $retry of $maxRetries)"
                    continue
                }
                else {
                    Write-Error "Error executing command: $Command"
                    Write-Error "Error message: $errorMsg"
                    return $null
                }
            }
        }
        catch {
            Write-Error "Exception: $_"
            return $null
        }
    }
    
    Write-Error "Failed after $maxRetries retries"
    return $null
}

# Function to update credentials file
function Update-CredentialsFile {
    param (
        [string]$Name,
        [string]$Subject,
        [string]$Issuer = "https://token.actions.githubusercontent.com",
        [string[]]$Audiences = @("api://AzureADTokenExchange")
    )

    if (-not (Test-Path $Script:CredsFile)) {
        Write-Error "Credentials file not found. Please run step1_register_app.ps1 first"
        exit 1
    }

    # Read current content
    $credentials = Get-Content $Script:CredsFile | ConvertFrom-Json

    # Ensure azure.application exists
    if (-not $credentials.azure.PSObject.Properties.Match('application').Count) {
        Add-Member -InputObject $credentials.azure -NotePropertyName 'application' -NotePropertyValue @{}
    }

    # Ensure azure.application.oidcConfiguration exists
    if (-not $credentials.azure.application.PSObject.Properties.Match('oidcConfiguration').Count) {
        Add-Member -InputObject $credentials.azure.application -NotePropertyName 'oidcConfiguration' -NotePropertyValue @{
            federatedCredentials = @()
            configuredOn = ""
        }
    }

    # Create new credential entry
    $newCred = @{
        name = $Name
        subject = $Subject
        issuer = $Issuer
        audiences = $Audiences
        configuredOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    # Check if credential already exists
    $exists = $false
    foreach ($cred in $credentials.azure.application.oidcConfiguration.federatedCredentials) {
        if ($cred.name -eq $Name) {
            $exists = $true
            break
        }
    }

    # Add credential if it doesn't exist
    if (-not $exists) {
        $credentials.azure.application.oidcConfiguration.federatedCredentials += $newCred
        $credentials.azure.application.oidcConfiguration.configuredOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    # Save updated content
    $credentials | ConvertTo-Json -Depth 10 | Set-Content $Script:CredsFile
    Write-Host "Updated credentials file with federated credential: $Name"
}

# Function to create federated credential
function Create-FederatedCredential {
    param (
        [string]$Name,
        [string]$Subject,
        [string]$AppId
    )
    
    Write-Host "Checking for existing federated credential: $Name"
    $existingCreds = Execute-AzCommand "az ad app federated-credential list --id $AppId"
    if (-not $existingCreds) {
        Write-Error "Failed to list existing federated credentials"
        return $false
    }
    
    $existingCreds = $existingCreds | ConvertFrom-Json
    $existing = $existingCreds | Where-Object { $_.name -eq $Name }
    
    if ($existing) {
        Write-Host "Federated credential '$Name' already exists"
        # Update JSON even if credential exists to ensure consistency
        Update-CredentialsFile -Name $Name -Subject $Subject
        return $true
    }
    
    Write-Host "Creating new federated credential: $Name"
    $body = @{
        name = $Name
        issuer = "https://token.actions.githubusercontent.com"
        subject = $Subject
        audiences = @("api://AzureADTokenExchange")
    } | ConvertTo-Json -Compress
    
    $result = Execute-AzCommand "az ad app federated-credential create --id $AppId --parameters '$body'"
    if ($result) {
        Write-Host "Successfully created federated credential: $Name"
        Update-CredentialsFile -Name $Name -Subject $Subject
        return $true
    }
    else {
        Write-Error "Failed to create federated credential: $Name"
        return $false
    }
}

# Ensure Azure CLI is logged in
Ensure-LoggedIn

# Check if repository information file exists
$envDir = Join-Path $PSScriptRoot "../../../.env"
$credsFile = Join-Path $envDir "azure-credentials.json"

if (-not (Test-Path $credsFile)) {
    Write-Error "Error: Credentials file not found at $credsFile"
    Write-Error "Please run step1_register_app.ps1 first"
    exit 1
}

# Read configuration
$creds = Get-Content $Script:CredsFile | ConvertFrom-Json
$appId = $creds.azure.application.clientId
$repoInfo = $creds.github
if (-not $repoInfo) {
    Write-Error "GitHub repository information not found in credentials file"
    exit 1
}

# Create federated credentials for different environments
$environments = @(
    @{
        Name = "github-actions-production"
        Subject = "repo:$($repoInfo.organization)/$($repoInfo.repository):environment:production"
    },
    @{
        Name = "github-actions-staging"
        Subject = "repo:$($repoInfo.organization)/$($repoInfo.repository):environment:staging"
    },
    @{
        Name = "github-actions-dev"
        Subject = "repo:$($repoInfo.organization)/$($repoInfo.repository):environment:dev"
    },
    @{
        Name = "github-actions-main"
        Subject = "repo:$($repoInfo.organization)/$($repoInfo.repository):ref:refs/heads/main"
    }
)

# Initialize array to track federated credentials
$federatedCreds = @()
$success = $true

foreach ($env in $environments) {
    Write-Host "`nProcessing environment: $($env.Name)"
    if (Create-FederatedCredential -Name $env.Name -Subject $env.Subject -AppId $appId) {
        $federatedCreds += @{
            name = $env.Name
            subject = $env.Subject
            issuer = "https://token.actions.githubusercontent.com"
            audiences = @("api://AzureADTokenExchange")
            configuredOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
    else {
        $success = $false
        break
    }
}

if ($success) {
    # Update credentials file with OIDC configuration
    $oidcConfig = @{
        federatedCredentials = $federatedCreds
        configuredOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    Update-CredentialsFile -Field "azure.oidcConfiguration" -Value $oidcConfig
    
    Write-Host "`nAll federated credentials have been processed and recorded in credentials file"
    Write-Host "OIDC configuration is complete"
}
else {
    Write-Error "Failed to configure all federated credentials"
    exit 1
}
