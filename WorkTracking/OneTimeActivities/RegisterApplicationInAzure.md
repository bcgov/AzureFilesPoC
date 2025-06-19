# Registering an Azure Application for GitHub Actions

> **⚠️ IMPORTANT: This is a step-by-step guide. Complete one step at # Step 2c: Role assignments
# Note: For the purposes of this PoC, we're using specific roles instead of the broad 'Contributor' role
# This follows the principle of least privilege, granting only the permissions needed for the task
#
# The following roles are needed for this PoC:
# 1. Storage Account Contributor: To manage storage accounts
# 2. Network Contributor: To configure virtual networks (may be needed later)
#
# These role assignments must be done through the Azure Portal since the command line assignment
# may be restricted in your environment.
#
# For reference only (the command below will not work if you don't have sufficient privileges):
az role assignment create \
  --assignee $appRegistration \
  --role "Storage Account Contributor" \ in the Azure portal, then uncomment and proceed to the next step.**

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

## Get details and save to `WorkTracking\OneTimeActivities\AzureAppRegistrationDetails.txt`
```script
@"
>> # Azure Application Registration Details
>> Date Created: $(Get-Date -Format "yyyy-MM-dd HH:mm")
>>
>> AZURE_CLIENT_ID: $appRegistration
>> AZURE_TENANT_ID: $tenantId
>> AZURE_SUBSCRIPTION_ID: $subscriptionId
>>
>> Service Principal Object ID: e72f42f8-d9a1-4181-a0b9-5c8644a28aee
>> "@ | Out-File -FilePath ".\WorkTracking\OneTimeActivities\AzureAppRegistrationDetails.txt"
```


## Step 2: Grant Permissions to the Service Principal

```powershell
# Step 2a: Get the subscription ID (if you don't have it from earlier)
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
# 2. Network Contributor: For setting up VNets, subnets, and networking components
# 3. Private DNS Zone Contributor: For configuring DNS integration with private endpoints
# 4. Monitoring Contributor: For setting up monitoring and diagnostics

# These roles are derived from our PoC architecture requirements described in ArchitectureOverview.md,
# which includes Azure Files shares, network configuration, private endpoints, and monitoring components.
# This is commonly used to control access and permissions for applications interacting with Azure services.
# Examples:
# Storage Account Contributor: Can manage storage accounts.
# Reader: Can view existing resources, but can’t make changes.
# Storage Blob Data Contributor: Can read, write, and delete Azure Storage blobs.
# Key Vault Secrets User: Can read secrets in Azure Key Vault.
# First, assign Storage Account Contributor role (PRIORITY)
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



<!-- 
UNCOMMENT THIS SECTION AFTER COMPLETING STEP 2
========================================

## Step 3: Configure Federated Credentials (OIDC)

Federated credentials allow GitHub Actions to authenticate to Azure without storing secrets. This follows BC Government best practices for secure CI/CD implementation.

### BC Government OIDC Best Practices

As per BC Government guidelines:
- OpenID Connect (OIDC) is the recommended authentication method for GitHub Actions to securely access Azure subscriptions
- This method eliminates the need for storing long-lived credentials as GitHub secrets
- For accessing Azure data storage and databases, self-hosted runners on Azure are required as public access is not supported
- Microsoft provides sample Terraform code for deploying these runners in the `azure-lz-samples` repository

Reference: [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions)

```powershell
# Step 3a: Set your GitHub repository information
$githubOrg="<YOUR_GITHUB_ORG_OR_USERNAME>"  # Replace with your actual GitHub username or organization
$githubRepo="AzureFilesPoC"                 # The name of your repository

# Step 3b: Configure federated credentials for GitHub Actions
az ad app federated-credential create \
  --id $appRegistration \
  --parameters @- << EOF
{
  "name": "github-federated-identity",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${githubOrg}/${githubRepo}:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
EOF
```

**VERIFICATION POINT 5**:
- In the Azure Portal, go to Azure Active Directory > App registrations
- Find and click on your "ag-pssg-azure-files-poc-ServicePrincipal" app
- Go to Certificates & secrets > Federated credentials
- Verify the GitHub federated credential is listed

**AFTER COMPLETING STEP 3**:
1. Update the Progress Tracking table at the bottom of this document
2. After all verification points pass, uncomment Step 4 and proceed

========================================
-->

<!-- 
UNCOMMENT THIS SECTION AFTER COMPLETING STEP 3
========================================

## Step 4: Store Credentials as GitHub Secrets

In GitHub Actions with OIDC authentication, you need to store only the identity information (not secrets) needed to establish the federated trust relationship:

1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Add the following repository secrets:

   - `AZURE_CLIENT_ID`: The Application (client) ID ($appRegistration)
   - `AZURE_TENANT_ID`: Your Azure AD tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID

### Configuring GitHub Workflow Permissions

When creating GitHub workflows that use these secrets, ensure you add the following permissions in your workflow YAML:

```yaml
permissions:
  id-token: write # Required for OIDC authentication
  contents: read  # Required for repository access
```

This allows the workflow to request and receive an OIDC token from GitHub, which is then exchanged for an Azure access token using the `azure/login` action.

**VERIFICATION POINT 6**:
- In GitHub, go to Settings > Secrets and variables > Actions
- Verify all three secrets are present
- Do not share or expose these secret values

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

### Next Steps After Verification

Once this basic configuration is verified, you can:
- Implement Terraform workflows following the guidance in [BC Government IaC and CI/CD documentation](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- Configure self-hosted runners if needed for accessing private resources
- Develop more complex workflows with proper approvals for resource deployments

**VERIFICATION POINT 7**:
- The workflow should show green checkmarks for all steps
- The output should indicate successful connection to Azure

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
| 2 | Grant Permissions to Service Principal (Specific Roles) | In Progress | | |
| 3 | Configure Federated Credentials | Not Started | | |
| 4 | Store GitHub Secrets | Not Started | | |
| 5 | Verify Configuration | Not Started | | |

## Completion Date

- Registration started: [DATE]
- Registration completed: [DATE]

## Additional Notes

- For security reasons, we're using OIDC federation rather than client secrets.
- This service principal is dedicated to the Azure Files PoC project only.
