# Registering an Azure Application for GitHub Actions (OIDC)

> **⚠️ IMPORTANT: This is a step-by-step guide. Complete one step at a time, verify in the Azure portal, then uncomment and proceed to the next step.**

## Purpose

This document provides a step-by-step guide for registering an Azure application (service principal) specifically for use with GitHub Actions in the Azure Files Proof of Concept (PoC) project. The registration process establishes the authentication foundation and prerequisites required for secure, automated deployments using Terraform, GitHub Actions with an Azure CI/CD pipeline for infrastructure-as-code (IaC). By following this guide, you will ensure that all automation workflows have the necessary Azure identity, permissions, and security best practices in place before any infrastructure as code (IaC) implementation begins.

After completing this application registration process, refer to the [Validation Process](ValidationProcess.md) guide that provides a structured approach to verify the end-to-end Terraform, GitHub Actions, and Azure integration. This validation process serves as a pattern to follow for all subsequent resource creation in the PoC.

> **⚠️ CRITICAL: This application registration process is a PREREQUISITE that must be completed BEFORE implementing any Terraform automation with GitHub Actions.**

The application registration and service principal creation documented in this guide serve as the foundation for all subsequent automation work:

1. **Authentication Foundation**: The service principal created here provides the identity that GitHub Actions will use to authenticate to Azure.

2. **Required for Automation**: Terraform running in GitHub Actions cannot create its own service principal - it needs this pre-existing identity to function.

3. **Implementation Sequence**:
   - First: Complete this application registration process (manual, one-time setup)
   - Then: Develop and test Terraform code locally
   - Finally: Configure GitHub Actions and/or runners to use this identity for automated deployments

4. **Credential Usage**:
   - The credentials generated here (client ID, tenant ID, subscription ID) will be stored as GitHub secrets
   - These secrets will be referenced in GitHub Actions workflows for Azure authentication
   - No long-lived secrets are used when configuring OIDC (OpenID Connect) federation
   - All Terraform CI/CD pipelines will use these credentials for authentication

Once this registration process is complete, the service principal details will be stored as GitHub secrets and used in all subsequent automation workflows.

This document guides you through registering an Azure application (service principal) for use with GitHub Actions in the Azure Files PoC project. It is designed to ensure security, verifiability, and auditability through a carefully managed process.

## Overview

For GitHub Actions to authenticate with Azure, we need to register an application in Azure Active Directory. This creates a service principal that GitHub Actions can use to securely access Azure resources.

During this process, you will:

1. Create an app registration in Azure AD
2. Create a service principal for the application
3. Grant appropriate permissions to the service principal 
4. Configure federated credentials for OIDC authentication
5. Store necessary credentials as GitHub secrets
6. Verify the setup with a test workflow

## Prerequisites

- Azure account with permissions to create app registrations
- Access to the GitHub repository where actions will be configured
- PowerShell or Azure CLI installed

## Process Overview - Execute One Step at a Time

This document is designed to be executed one step at a time, with verification in the Azure portal after each step. To follow this process:

1. Execute only the commands in the current active step
2. Complete all verification points for that step
3. Once verified, uncomment the next step and proceed
4. Document your progress and any issues encountered

> **IMPORTANT**: All steps after Step 1 are commented out. Uncomment each step ONLY after successfully completing and verifying the previous step.

## Step 1: Register an Application in Azure AD

```powershell
# Step 1a: Log in to Azure and verify subscription
az login

# Set the subscription context (if you have multiple subscriptions)
az account set --subscription "<SUBSCRIPTION_ID>"

# Read account info to verify
az account show
```

This should return information like:
```json
{
  "environmentName": "AzureCloud",
  "homeTenantId": "",
  "id": "",
  "isDefault": true,
  "managedByTenants": [],
  "name": "namespace info",
  "state": "Enabled",
  "tenantDefaultDomain": "bcgov.onmicrosoft.com",
  "tenantDisplayName": "Government of BC",
  "tenantId": "",
  "user": {
    "name": "Richard.Fremmerlid@gov.bc.ca",
    "type": "user"
  }
}
```

**VERIFICATION POINT 1**: Make sure you're logged in and using the correct subscription before proceeding.

```powershell
# Step 1b: Create the app registration
$appName="ag-pssg-azure-files-poc-ServicePrincipal"
$appRegistration=$(az ad app create --display-name "$appName" --query appId -o tsv)
echo "App Registration ID: $appRegistration"

# Save the app registration ID for later steps - WRITE IT DOWN
```

**VERIFICATION POINT 2**: 
- Go to the Azure Portal
- Navigate to Azure Active Directory > App registrations
- Verify the "ag-pssg-azure-files-poc-ServicePrincipal" app appears in the list
- Note the Application (client) ID for future use

```powershell
# Step 1c: Create a service principal for the application
az ad sp create --id $appRegistration
```

**VERIFICATION POINT 3**:
- In the Azure Portal, go to Azure Active Directory > Enterprise applications
- Verify the service principal appears in the list
- Note: The service principal name will match your app registration name

**AFTER COMPLETING STEP 1**:
1. Update the Progress Tracking table at the bottom of this document
2. After all verification points pass, uncomment Step 2 and proceed

## Get details and save to `.\env\azure-credentials.json`
```powershell
# Get tenant ID and subscription ID
$tenantId=$(az account show --query tenantId -o tsv)
$subscriptionId=$(az account show --query id -o tsv)

# Create the .env directory if it doesn't exist
if (!(Test-Path -Path ".\\.env")) {
    New-Item -ItemType Directory -Path ".\\.env" | Out-Null
    Write-Host "Created .env directory"
}

# Get service principal object ID
$servicePrincipalObjId=$(az ad sp show --id $appRegistration --query id -o tsv)

# Create JSON credential object
$credentials = @{
  "metadata" = @{
    "dateCreated" = (Get-Date -Format "yyyy-MM-dd HH:mm")
    "appRegistrationName" = $appName
  }
  "azure" = @{
    "clientId" = $appRegistration
    "tenantId" = $tenantId
    "subscriptionId" = $subscriptionId
    "servicePrincipalObjectId" = $servicePrincipalObjId
  }
  "github" = @{
    "org" = "bcgov"
    "repo" = "AzureFilesPoC"
  }
}

# Save to JSON file
$credentials | ConvertTo-Json -Depth 3 | Out-File -FilePath ".\\.env\\azure-credentials.json"
Write-Host "Azure credentials saved to .env/azure-credentials.json"

# Display confirmation
Write-Host "Saved the following details:"
Write-Host "- Client ID: $appRegistration"
Write-Host "- Tenant ID: $tenantId"
Write-Host "- Subscription ID: $subscriptionId"
Write-Host "- Service Principal Object ID: $servicePrincipalObjId"
```


## Step 2: Grant Permissions to the Service Principal

```powershell
# Step 2a: Log in to Azure and set the subscription context
az login

# Verify the current subscription
$currentSubscription = az account show --query name -o tsv
$currentSubscriptionId = az account show --query id -o tsv
Write-Host "Using subscription: $currentSubscription ($currentSubscriptionId)"
Write-Host "If this is not the correct subscription, use 'az account set --subscription <SUBSCRIPTION_ID>'"

# Set the subscription context (if you have multiple subscriptions)
# az account set --subscription "<SUBSCRIPTION_ID>"

# Get the subscription ID
$subscriptionId=$(az account show --query id -o tsv)
echo "Subscription ID: $subscriptionId"

# Step 2b: Get App registration ID
$appRegistration=$(Get-Content .\WorkTracking\OneTimeActivities\AzureAppRegistrationDetails.txt | Select-String -Pattern "AZURE_CLIENT_ID: " | ForEach-Object { $_ -replace "AZURE_CLIENT_ID: ", "" })
echo "Using App Registration ID: $appRegistration"

# Step 2c: Role assignments
# Note: For the purposes of this PoC, we're using specific roles instead of the broad 'Contributor' role
# This follows the principle of least privilege, granting only the permissions needed for the task
#
# We're assigning these specific roles based on our PoC architecture requirements:
# 1. Storage Account Contributor: For managing storage accounts (CORE)
# 2. Network Contributor: For VNets, subnets, and networking components
# 3. Private DNS Zone Contributor: For DNS integration with private endpoints
# 4. Monitoring Contributor: For monitoring and diagnostics
#
# Execute the following commands to assign these roles:

# 1. Storage Account Contributor: For managing storage accounts hosting Azure Files shares
az role assignment create \
  --assignee $appRegistration \
  --role "Storage Account Contributor" \
  --scope /subscriptions/$subscriptionId

# Next, assign Network Contributor role
az role assignment create \
  --assignee $appRegistration \
  --role "Network Contributor" \
  --scope /subscriptions/$subscriptionId

# Next, assign Private DNS Zone Contributor role
az role assignment create \
  --assignee $appRegistration \
  --role "Private DNS Zone Contributor" \
  --scope /subscriptions/$subscriptionId

# Finally, assign Monitoring Contributor role
az role assignment create \
  --assignee $appRegistration \
  --role "Monitoring Contributor" \
  --scope /subscriptions/$subscriptionId
```
**VERIFICATION WITH CODE**: 
```powershell
# Check all role assignments for your service principal
az role assignment list --assignee $appRegistration --output table

# Expected output should show 4 role assignments:
# - Storage Account Contributor
# - Network Contributor
# - Private DNS Zone Contributor
# - Monitoring Contributor
```

**VERIFICATION POINT 4**:
- In the Azure Portal, go to Subscriptions > [Your Subscription]
- Click on Access control (IAM)
- Click on "Role assignments" tab
- Verify your service principal has all four of the assigned roles:
  - "Storage Account Contributor" (most critical)
  - "Network Contributor"
  - "Private DNS Zone Contributor" 
  - "Monitoring Contributor"
- Alternatively, verify using the command line by running:
  ```powershell
  az role assignment list --assignee $appRegistration --output table
  ```
- Confirm that the output shows all four role assignments with the correct scope

**Note on Required Permissions**: 
Based on the architecture in ArchitectureOverview.md, the Azure Files PoC involves:
1. Storage accounts with Azure File Shares and optionally Blob Storage
2. Virtual Networks with subnets and private endpoints
3. Private DNS zones for name resolution

The "Storage Account Contributor" role is the most critical for the core functionality. If your environment restricts role assignments, this should be your priority role.

**AFTER COMPLETING STEP 2**:
1. Update the Progress Tracking table at the bottom of this document
2. After all verification points pass, uncomment Step 3 and proceed

### Azure Roles for Azure Files PoC Architecture

Below is a mapping of the recommended Azure roles to the specific components from our PoC architecture:

| **Role** | **Applies To Architecture Components** | **Why It's Needed** |
|----------|--------------------------------------|---------------------|
| **Storage Account Contributor** | - Azure Files (Premium/Standard)<br>- Azure Storage Account<br>- Azure Blob Storage | Core role for creating and managing storage accounts that host Azure Files shares and blob containers |
| **Network Contributor** | - Azure Virtual Network (Hub/Spoke)<br>- Subnets<br>- NSGs<br>- Private Endpoints | For configuring the networking components required for secure access to Azure Files via private endpoints |
| **Private DNS Zone Contributor** | - Private DNS Zone | For configuring name resolution for private endpoints |
| **Monitoring Contributor** | - Azure Monitor<br>- Log Analytics | For setting up diagnostic settings, metrics, and alerts |

For minimal permissions, the **Storage Account Contributor** is the most essential role for this PoC, as it allows management of the core Azure Files infrastructure. Add other roles as needed based on which components you'll be deploying.

Reference: This role mapping is derived from the components described in the [ArchitectureOverview.md](../ArchitectureOverview.md) document.



## Step 3: Configure Federated Credentials (OIDC)

Federated credentials allow GitHub Actions to authenticate to Azure without storing secrets. This follows BC Government best practices for secure CI/CD implementation.

### OIDC Federated Credentials Overview

OpenID Connect (OIDC) federation enables secure, passwordless authentication between GitHub Actions and Azure. Instead of storing long-lived secrets, you create a federated credential in your Azure AD application that establishes a trust relationship with GitHub. This credential specifies which GitHub repository, branch, or environment is allowed to request tokens for your Azure app.

When a GitHub Actions workflow runs, it requests a special OIDC token from GitHub. Azure validates this token against the federated credential configuration. If the request matches the allowed repository and branch/environment, Azure issues a short-lived access token to the workflow. This allows GitHub Actions to authenticate to Azure securely, following best practices and reducing the risk of credential leaks.

For an in-depth understanding of workload identity federation with OIDC, refer to [Introduction to Azure DevOps workload identity federation (OIDC) with Terraform](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/).

Key points:
- Federated credentials are configured in Azure AD for your app registration.
- Each credential references your GitHub organization, repository, and optionally branch or environment.
- No secrets are stored in GitHub; authentication is handled dynamically via OIDC tokens.
- This approach is recommended for secure CI/CD pipelines and aligns with BC Government best practices.

### BC Government OIDC Best Practices

As per BC Government guidelines:
- OpenID Connect (OIDC) is the recommended authentication method for GitHub Actions to securely access Azure subscriptions
- This method eliminates the need for storing long-lived credentials as GitHub secrets
- For accessing Azure data storage and databases, self-hosted runners on Azure are required as public access is not supported
- Microsoft provides sample Terraform code for deploying these runners in the `azure-lz-samples` repository
- You store identity information (NOT secrets) as GitHub secrets
- the secrets include:   
    AZURE_CLIENT_ID (the application/client ID)
    AZURE_TENANT_ID (your Azure tenant ID)
    AZURE_SUBSCRIPTION_ID (your subscription ID)

Process: 
1. When a GitHub workflow runs, it requests a special OIDC token from GitHub
2. This token is sent to Azure AD
3. Azure AD verifies the token came from the trusted GitHub repository
4. If verified, Azure AD issues a short-lived access token for Azure resources

Reference: [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions)

---

### Configure Federated Credentials (OIDC) — Substeps and Status

#### sub-Steps
| Substep | Description                                                      | Status      |
|---------|------------------------------------------------------------------|-------------|
| 3a      | Get App registration ID from JSON file and GitHub info           | Not Started |
| 3b      | Configure federated credentials for GitHub Actions main branch   | Not Started |
| 3c      | Configure federated credentials for pull requests                | Not Started |
| 3d      | Configure federated credentials for environment deployments      | Not Started |

**NOTE:** Update the status column as you complete each substep.

```powershell
# Step 3a: Log in to Azure and set subscription context
az login

# Clear any cached tokens to avoid "InteractionRequired" errors
az account clear
az login

# Set the subscription context (if you have multiple subscriptions)
# az account set --subscription "<SUBSCRIPTION_ID>"

# Verify the current subscription
$currentSubscription = az account show --query name -o tsv
$currentSubscriptionId = az account show --query id -o tsv
Write-Host "Using subscription: $currentSubscription ($currentSubscriptionId)"
Write-Host "If this is not the correct subscription, use 'az account set --subscription <SUBSCRIPTION_ID>'"

# Verify permissions - ensure your account has the necessary roles (e.g., Application Administrator)
Write-Host "Verifying your permissions for managing application credentials..."
az role assignment list --assignee (az account show --query user.name -o tsv) --output table
Write-Host "Make sure you have Application Administrator, Cloud Application Administrator, or Global Administrator roles"

# Get App registration ID and GitHub info from JSON file
$appCredentials = Get-Content ".\\.env\\azure-credentials.json" | ConvertFrom-Json

# Extract values from the JSON structure
$appRegistration = $appCredentials.azure.clientId
$tenantId = $appCredentials.azure.tenantId
$subscriptionId = $appCredentials.azure.subscriptionId
$githubOrg = $appCredentials.github.org
$githubRepo = $appCredentials.github.repo

# Verify Azure login and subscription
Write-Host "Verifying Azure login..."
az account show -o table

Write-Host "Using App Registration ID: $appRegistration"
Write-Host "Using Tenant ID: $tenantId"
Write-Host "Using Subscription ID: $subscriptionId"
Write-Host "Using GitHub Organization: $githubOrg" 
Write-Host "Using GitHub Repository: $githubRepo"

# Step 3b: Configure federated credentials for GitHub Actions main branch
Write-Host "Creating federated credential for main branch"
$fedCredMainBranch = @{
    name = "github-federated-identity-main-branch"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:${githubOrg}/${githubRepo}:ref:refs/heads/main"
    audiences = @("api://AzureADTokenExchange")
}

# Create a temporary JSON file for main branch credential
$tempMainJsonPath = Join-Path $env:TEMP "maincred_$(Get-Random).json"
$fedCredMainBranch | ConvertTo-Json | Out-File -FilePath $tempMainJsonPath

Write-Host "Creating federated credential for main branch using file: $tempMainJsonPath"

# Create the federated credential for main branch using the JSON file
az ad app federated-credential create --id $appRegistration --parameters "@$tempMainJsonPath"

# Clean up temporary file
Remove-Item -Path $tempMainJsonPath -Force

# Step 3c: Configure additional federated credentials for pull requests
Write-Host "Creating federated credential for pull requests"
$fedCredPullRequests = @{
    name = "github-federated-identity-pull-requests"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:${githubOrg}/${githubRepo}:pull_request"
    audiences = @("api://AzureADTokenExchange")
}

# Create a temporary JSON file for pull requests credential
$tempPRJsonPath = Join-Path $env:TEMP "prcred_$(Get-Random).json"
$fedCredPullRequests | ConvertTo-Json | Out-File -FilePath $tempPRJsonPath

Write-Host "Creating federated credential for pull requests using file: $tempPRJsonPath"

# Create the federated credential for pull requests using the JSON file
az ad app federated-credential create --id $appRegistration --parameters "@$tempPRJsonPath"

# Clean up temporary file
Remove-Item -Path $tempPRJsonPath -Force

# Step 3d: Configure federated credentials for environment-specific deployments
# Only configure federated credentials for the `dev` environment

# Configure federated credentials for environments
# For now, we only set up the 'dev' environment
$environments = @("dev") # Add "test", "prod" when/if needed

foreach ($env in $environments) {
    Write-Host "Creating federated credential for environment: $env"
    $fedCredEnvironment = @{
        name = "github-federated-identity-${env}-environment"
        issuer = "https://token.actions.githubusercontent.com"
        subject = "repo:${githubOrg}/${githubRepo}:environment:${env}"
        audiences = @("api://AzureADTokenExchange")
    }
      # Create a temporary JSON file for environment credential
    $tempEnvJsonPath = Join-Path $env:TEMP "envcred_$(Get-Random).json"
    $fedCredEnvironment | ConvertTo-Json | Out-File -FilePath $tempEnvJsonPath

    Write-Host "Creating federated credential for environment $env using file: $tempEnvJsonPath"
    
    # Create the federated credential for environment using the JSON file
    az ad app federated-credential create --id $appRegistration --parameters "@$tempEnvJsonPath"
    
    # Clean up temporary file
    Remove-Item -Path $tempEnvJsonPath -Force
}
```

**VERIFICATION POINT 5**:
- In the Azure Portal, go to Microsoft Entra ID (formerly Azure Active Directory)
- Navigate to App registrations > All applications
- Find and click on your "ag-pssg-azure-files-poc-ServicePrincipal" app
- Go to Certificates & secrets > Federated credentials
- Verify that all GitHub federated credentials are listed:
  - `github-federated-identity-main-branch` for main branch
  - `github-federated-identity-pull-requests` for pull requests
  - `github-federated-identity-dev-environment` for dev environment

**Verification Using Azure CLI**:
```powershell
# List all federated credentials for the app registration
az ad app federated-credential list --id $appRegistration --query "[].{Name:name, Subject:subject}" -o table

# Expected output should show all federated credentials configured above
# For example:
# Name                                     Subject
# ---------------------------------------  ---------------------------------------------
# github-federated-identity-main-branch    repo:bcgov/AzureFilesPoC:ref:refs/heads/main
# github-federated-identity-pull-requests  repo:bcgov/AzureFilesPoC:pull_request
# github-federated-identity-dev-environment repo:bcgov/AzureFilesPoC:environment:dev
```

### Troubleshooting OIDC Configuration Issues

If you encounter the error `InteractionRequired` with code `TokenCreatedWithOutdatedPolicies` or other errors when running the `az ad app federated-credential create` command, follow these troubleshooting steps:

#### Clear Azure CLI Cache and Re-authenticate
The token might be cached and no longer valid due to updated policies:

```powershell
# Clear token cache
az account clear

# Re-authenticate
az login

# If using service principal
# az login --service-principal -u <client-id> -p <client-secret> --tenant <tenant-id>
```

#### Verify Conditional Access Policies
Check if a new Conditional Access policy in Microsoft Entra ID requires additional authentication factors:
- Sign in to the Azure portal
- Navigate to Microsoft Entra ID > Security > Conditional Access
- Review policies applied to the user or service principal

#### Check Token Lifetime Policies
The error might be caused by a token issued with a lifetime that no longer complies with policies:

```powershell
# Check sign-in audience
az ad app show --id $appRegistration --query "signInAudience"
```

#### Validate Federated Credential Configuration
Ensure the parameters in your temporary JSON file are correct:
- `issuer`: Must be exactly `https://token.actions.githubusercontent.com` for GitHub Actions
- `subject`: Format is `repo:org/repo:ref:refs/heads/branch` for branches or `repo:org/repo:pull_request` for PRs
- `audiences`: Should be `["api://AzureADTokenExchange"]`

#### Check Permissions
Ensure you have sufficient permissions to create federated credentials:

```powershell
# List roles for current user
az role assignment list --assignee (az account show --query user.name -o tsv) --output table

# List existing federated credentials (max 20 allowed)
az ad app federated-credential list --id $appRegistration
```

#### Verify Application ID
Make sure you're using the correct application ID (not object ID):

```powershell
# Find the correct app ID
az ad app list --display-name "$appName" --query '[0].id' -o tsv
```

For more detailed guidance, refer to the [Azure DevOps workload identity federation documentation](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/).

---

**AFTER COMPLETING STEP 3**:
1. Update the Progress Tracking table at the bottom of this document
2. After all verification points pass, uncomment Step 4 and proceed

## Step 4: Store GitHub Secrets

In this step, you will store the necessary credentials as GitHub secrets. These secrets will be used by GitHub Actions to authenticate to Azure.

1. Navigate to your GitHub repository
2. Go to Settings > Secrets and variables > Actions
3. Click on "New repository secret" for each of the following secrets:
   - `AZURE_CLIENT_ID`: The Application (client) ID of your app registration
   - `AZURE_TENANT_ID`: Your Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

> **IMPORTANT**: Do not share or expose these secret values. They are sensitive credentials that allow access to your Azure resources.

**AFTER COMPLETING STEP 4**:
1. Update the Progress Tracking table at the bottom of this document
2. After all verification points pass, uncomment Step 5 and proceed

========================================
-->

<!-- 
UNCOMMENT THIS SECTION AFTER COMPLETING STEP 4
========================================

## Step 5: Verify Configuration

This step verifies the OIDC federation is working correctly by running a test workflow. Following BC Government best practices, we start with a simple login test before implementing more complex workflows.

### Running the Azure Login Test

1. Navigate to the GitHub Actions tab in your repository
2. Run the "Azure Login Test" workflow (`.github/workflows/azure-login-test.yml`)
3. Verify that the workflow completes successfully without errors

The test workflow contains the following key components:
- Permission settings for OIDC token access
- The azure/login action configured with your secrets
- A minimal az CLI command to verify authentication works
- No resource modification or creation

### Validating the Overall CI/CD Framework

After confirming basic Azure authentication, validate the end-to-end CI/CD pipeline using the dedicated validation workflow:

1. Navigate to the GitHub Actions tab in your repository
2. Run the "Terraform Validation Workflow" (`.github/workflows/terraform-validation.yml`)
3. Use the following settings:
   - **Environment**: `dev` (or your target environment)
   - **Cleanup**: `true` (to automatically remove test resources)
4. Verify the workflow can successfully:
   - Authenticate to Azure using OIDC
   - Initialize Terraform
   - Plan and apply the configuration
   - Verify resource creation
   - Delete the test resource after validation

This validation workflow uses a minimal Terraform configuration located in `terraform/validation/` that creates only a simple resource group to verify all components are working together:

- Application registration and OIDC federation
- GitHub Actions workflow configuration
- Terraform authentication and permissions
- GitHub Secrets integration
- End-to-end resource creation and cleanup

For detailed steps, refer to the [Validation Process](ValidationProcess.md) guide, which serves as a pattern for all future resource creation in this PoC.

### Next Steps After Verification

Once the end-to-end verification is complete, you can:
- Begin implementing production Terraform code following the guidance in [BC Government IaC and CI/CD documentation](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- Configure self-hosted runners if needed for accessing private resources
- Develop more complex workflows with proper approvals for resource deployments

**VERIFICATION POINT 7**:
- Both login and Terraform validation workflows show green checkmarks for all steps
- The output indicates successful connection to Azure and resource creation
- Test resources are automatically cleaned up after validation
- All validation criteria in the [Validation Process](ValidationProcess.md) are met

**AFTER COMPLETING STEP 5**:
1. Update the Progress Tracking table at the bottom of this document
2. Mark the registration process as complete
3. Document the completion date

========================================
-->

## Security Considerations

- The service principal has been granted specific roles (Storage Account Contributor, Network Contributor, Private DNS Zone Contributor, and Monitoring Contributor) aligned with the principle of least privilege.
- Regularly rotate credentials or consider using shorter-lived credentials.
- Monitor service principal activity through Azure Activity Logs.
- Consider further restricting roles to specific resource groups rather than subscription-level scope in production environments.

## Progress Tracking

Use this section to track your progress through the steps. Update this as you complete each step.

| Step | Description | Status | Completed By | Date |
|------|-------------|--------|-------------|------|
| 1 | Register Application in Azure AD | Completed | | [DATE] |
| 2 | Grant Permissions to Service Principal (Specific Roles) | Completed | | [DATE] |
| 3 | Configure Federated Credentials | In Progress | | |
| 4 | Store GitHub Secrets | Not Started | | |
| 5a | Verify Azure Login | Not Started | | |
| 5b | Validate Terraform Pipeline | Not Started | | |
| 6 | Document Completed Setup | Not Started | | |

## Completion Date

- Registration started: [DATE]
- Registration completed: [DATE]

## Additional Notes

- For security reasons, we're using OIDC federation rather than client secrets.
- This service principal is dedicated to the Azure Files PoC project only.
- The credentials from this registration process are used in multiple places:
  - GitHub Actions workflows for direct Azure operations
  - Terraform running in GitHub Actions for infrastructure deployment
  - Any CI/CD pipelines that need to interact with Azure resources
