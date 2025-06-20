# Script to grant required Azure roles to the application
# Requires: Azure CLI, PowerShell 5.1 or higher

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
$Script:RequiredRoles = @(
    # Base roles
    "Reader",
    "Storage Account Contributor",
    "[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor",
    "Private DNS Zone Contributor",
    "Monitoring Contributor",
    
    # Storage-specific roles
    "Storage Account Backup Contributor",
    "Storage Blob Data Owner",
    "Storage File Data Privileged Contributor",
    "Storage File Data SMB Share Elevated Contributor",
    "Storage Blob Delegator",
    "Storage File Delegator",
    
    # Additional data plane roles
    "Storage Queue Data Contributor",
    "Storage Table Data Contributor",
    "DNS Resolver Contributor",
    "Azure Container Storage Contributor"
)

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

# Function to update role assignments in credentials file
function Update-RoleAssignments {
    param (
        [array]$NewRoleAssignments
    )
    
    # Read current content
    $credentials = Get-Content $Script:CredsFile | ConvertFrom-Json
    
    # Add new role assignments only if they don't already exist
    foreach ($newRole in $NewRoleAssignments) {
        $existingRole = $credentials.azure.subscription.roleAssignments | 
            Where-Object { $_.roleName -eq $newRole.roleName }
            
        if (-not $existingRole) {
            $credentials.azure.subscription.roleAssignments += $newRole
        }
    }
    
    # Save updated content
    $credentials | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
    Write-Host "Updated role assignments in credentials file"
}

# Function to clean up role assignments in JSON
function Clear-EmptyRoleAssignments {
    Write-Host "Cleaning up empty role assignments in credentials file..."
    
    # Read current content
    $credentials = Get-Content $Script:CredsFile | ConvertFrom-Json
    
    # Filter out empty role assignments while keeping valid ones
    $validRoleAssignments = $credentials.azure.subscription.roleAssignments | Where-Object {
        $_ -and 
        $_.roleName -and 
        $_.principalId -and 
        $_.scope -and 
        ![string]::IsNullOrWhiteSpace($_.roleName) -and
        ![string]::IsNullOrWhiteSpace($_.principalId) -and
        ![string]::IsNullOrWhiteSpace($_.scope)
    }
    
    # Update with cleaned role assignments
    $credentials.azure.subscription.roleAssignments = @($validRoleAssignments)
    
    # Save updated content
    $credentials | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
}

# Verify prerequisites
Verify-Prerequisites

# Check if credentials file exists
if (-not (Test-Path $Script:CredsFile)) {
    Write-Error "Error: Credentials file not found at $($Script:CredsFile)"
    Write-Error "Please run step1_register_app.ps1 first"
    exit 1
}

# Read credentials from correct paths
$creds = Get-Content $Script:CredsFile | ConvertFrom-Json
$appId = $creds.azure.ad.application.clientId
$subscriptionId = $creds.azure.subscription.id
$principalId = $creds.azure.ad.application.servicePrincipalObjectId

# Initialize roleAssignments array if it doesn't exist
if (-not $creds.azure.subscription) {
    $creds.azure | Add-Member -NotePropertyName 'subscription' -NotePropertyValue @{
        id = $subscriptionId
        roleAssignments = @()
    }
    $creds | ConvertTo-Json -Depth 6 | Set-Content $Script:CredsFile
}

# Ensure logged in
Write-Host "Checking Azure CLI login status..."
$loginCheck = Execute-AzCommand "az account show"
if (-not $loginCheck) {
    Write-Host "Please complete the login process in your browser..."
    $loginResult = Execute-AzCommand "az login --scope 'https://graph.microsoft.com//.default'"
    if (-not $loginResult) {
        Write-Error "Login failed. Please try again."
        exit 1
    }
}

# Display current context and ask for confirmation
Write-Host "`nCurrent Azure context:"
Execute-AzCommand "az account show -o table"
Write-Host "`nPress Enter to continue with this context, or Ctrl+C to exit and run 'az login' with different credentials"
Read-Host

# Get existing role assignments
Write-Host "Getting existing role assignments..."
$existingRoles = Execute-AzCommand "az role assignment list --assignee $appId --subscription $subscriptionId"
if (-not $existingRoles) {
    Write-Error "Failed to get existing role assignments"
    exit 1
}
$existingRoles = $existingRoles | ConvertFrom-Json

# Initialize array to track assigned roles
$assignedRoles = @()

foreach ($role in $requiredRoles) {
    Write-Host "`nProcessing role: $role"
    
    # Check if role is already assigned
    $hasRole = $existingRoles | Where-Object { $_.roleDefinitionName -eq $role }
    if ($hasRole) {
        Write-Host "Role '$role' is already assigned"
        $assignedRoles += @{
            name = $role
            id = $hasRole.id
            principalId = $hasRole.principalId
            scope = $hasRole.scope
            assignedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
        continue
    }
    
    # Assign the role
    Write-Host "Assigning role '$role'..."
    $result = Execute-AzCommand "az role assignment create --assignee $appId --role '$role' --subscription $subscriptionId"
    if ($result) {
        Write-Host "Successfully assigned role '$role'"
        $newAssignment = $result | ConvertFrom-Json
        $assignedRoles += @{
            name = $role
            id = $newAssignment.id
            principalId = $newAssignment.principalId
            scope = $newAssignment.scope
            assignedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }
    }
    else {
        Write-Error "Failed to assign role '$role'"
        exit 1
    }
}

# Update credentials file with role assignments
Update-RoleAssignments -RoleAssignments $assignedRoles

Write-Host "`nAll required roles have been processed and recorded in credentials file"

# Function to assign all missing roles
function Assign-MissingRoles {
    param (
        [string[]]$RolesToAssign
    )
    
    # Clean up existing role assignments first
    Clear-EmptyRoleAssignments
    
    $assignedCount = 0
    $failedCount = 0
    $failedRoles = @()
    $assignedRoles = @()
    
    Write-Host "`nStarting role assignments..."
    Write-Host "This may take a few minutes..."
    
    foreach ($role in $RolesToAssign) {
        Write-Host "Assigning role: $role... " -NoNewline
        
        # Attempt to assign the role
        $result = Execute-AzCommand "az role assignment create --assignee `"$appId`" --role `"$role`" --subscription `"$subscriptionId`""
        if ($result) {
            $roleAssignment = $result | ConvertFrom-Json
            $assignedRoles += @{
                roleName = $role
                principalId = $roleAssignment.principalId
                scope = $roleAssignment.scope
                assignedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            Write-Host "Done" -ForegroundColor Green
            $assignedCount++
        }
        else {
            Write-Host "Failed" -ForegroundColor Red
            $failedCount++
            $failedRoles += $role
        }
    }
    
    # Update credentials file with all new role assignments
    if ($assignedCount -gt 0) {
        Update-RoleAssignments -RoleAssignments $assignedRoles
    }
    
    # Print summary
    Write-Host "`nRole assignment complete:"
    Write-Host "- Successfully assigned: $assignedCount roles"
    if ($failedCount -gt 0) {
        Write-Host "- Failed to assign: $failedCount roles"
        Write-Host "Failed roles:"
        $failedRoles | ForEach-Object { Write-Host "  - $_" }
    }
}

# Main role assignment logic
Write-Host "`nChecking existing role assignments..."

# Get existing role assignments
$existingRoles = Execute-AzCommand "az role assignment list --assignee `"$appId`" --subscription `"$subscriptionId`" --query '[].roleDefinitionName'" | ConvertFrom-Json

Write-Host "`nExisting role assignments:"
if ($existingRoles) {
    $existingRoles | ForEach-Object { Write-Host "- $_" }
} else {
    Write-Host "- None found"
}

# Find missing roles
$rolesToAssign = @()
foreach ($role in $Script:RequiredRoles) {
    if ($role -notin $existingRoles) {
        $rolesToAssign += $role
    }
}

Write-Host "`nMissing roles that need to be assigned:"
if ($rolesToAssign.Count -eq 0) {
    Write-Host "- All required roles are already assigned"
} else {
    $rolesToAssign | ForEach-Object { Write-Host "- $_" }
    
    Write-Host "`nWould you like to assign these missing roles? (y/n)"
    $confirm = Read-Host
    if ($confirm -eq 'y') {
        Assign-MissingRoles -RolesToAssign $rolesToAssign
    } else {
        Write-Host "Skipping role assignments"
    }
}
