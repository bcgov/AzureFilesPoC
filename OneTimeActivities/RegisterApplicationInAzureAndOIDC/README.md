# Custom Role: [PROJECT-PREFIX]-role-assignment-writer

As part of the onboarding process, we created a custom Azure role named `<project-name>-role-assignment-writer` through the Azure Portal. This role grants only the minimum permissions required for the pipeline's service principal to create and read role assignments (specifically, `Microsoft.Authorization/roleAssignments/write` and `read`) at the resource group scope. 

**Why this is needed:**
- Azure policy and BC Gov security standards require least-privilege access for automation.
- The built-in roles did not provide the exact permissions needed for the pipeline to assign data plane roles (e.g., Storage File Data SMB Share Contributor) to itself or other identities.
- This custom role enables the GitHub Actions pipeline to automate Azure File Share creation and related RBAC assignments, while preventing broader or unnecessary access.
- The custom role name follows BC Gov naming conventions for clarity and auditability.

The custom role definition is stored at `scripts/<project-name>-role-assignment-writer.json` for reference and re-use.

---

# Register Azure Application & Configure OIDC for GitHub Actions

## 📚 Documentation Quick Links

- **[TROUBLESHOOTING_GUIDE.md](./TROUBLESHOOTING_GUIDE.md)** - Comprehensive troubleshooting for all onboarding issues
- **[SSH_KEY_REFERENCE.md](./SSH_KEY_REFERENCE.md)** - Complete SSH key management and Bastion connection guide
- **[scripts/unix/](./scripts/unix/)** - All automated onboarding scripts with detailed inline documentation

## ⚠️ Security Model: Two Identities, Two Phases

- **Your User Identity (High Privilege):** Used for one-time setup (registering app, creating resource group). Has Contributor/Owner rights.
- **Pipeline Service Principal (Low Privilege):** Used by GitHub Actions. Can only create resources inside existing resource groups. Cannot create resource groups.

**Principle of Least Privilege:**
- Only assign roles at the subscription level that are truly required across the entire subscription (see Step 2 below).
- Storage/data plane roles (e.g., Storage Blob Data Contributor, Storage File Data SMB Share Contributor) should NOT be assigned at the subscription level. Assign these at the storage account or resource group level for least privilege and better security.
- See onboarding scripts for examples and comments.

This separation enforces the Principle of Least Privilege and aligns with BC Gov security standards.

---

## Onboarding Steps (What To Do)

**All scripts are fully automated, idempotent, and safe to re-run. Run each script in order, verifying each step before proceeding.**

### Phase 1: Core Identity and Authentication Setup

1. **Register Application in Azure**  
   _User Identity Required_  
   - `./scripts/unix/step1_register_app.sh`
   - Creates Azure AD application and service principal for GitHub Actions

2. **Grant Subscription-Level Permissions**  
   _User Identity Required_  
   - `./scripts/unix/step2_grant_subscription_level_permissions.sh` 
   - Assigns only essential roles at subscription level (Reader, Network-Subnet-Contributor)
   - **Note:** Storage/data plane roles are assigned at resource group level in step 6.2

3. **Configure OIDC Federated Credentials**  
   _User Identity Required_  
   - `./scripts/unix/step3_configure_github_oidc_federation.sh` 
   - Enables secure, passwordless authentication between GitHub Actions and Azure

4. **Prepare GitHub Secrets**  
   _User Identity Required_  
   - `./scripts/unix/step4_prepare_github_secrets.sh` 
   - Displays values needed for GitHub repository secrets

5. **Add GitHub Secrets (Automated)**  
   _User Identity Required_  
   - `./scripts/unix/step5_add_github_secrets_cli.sh`
   - Automatically adds all required secrets to GitHub repository

### Phase 2: Resource Group and Role Setup

6. **Create Permanent Resource Groups**  
   _User Identity Required_  
   - `./scripts/unix/step6_create_resource_group.sh`
   - Creates all required resource groups with proper tags and policy compliance
   - **Restored and enhanced** - contrary to previous notes, this script is active and working

6.1. **Create Custom Roles**  
   _User Identity Required_  
   - `./scripts/unix/step6.1_CreateCustomRole.sh`
   - Creates custom Azure roles with minimal required permissions
   - Handles both role creation and updates idempotently

6.2. **Assign Roles to Resource Groups**  
   _User Identity Required_  
   - `./scripts/unix/step6.2_assign_roles_to_resource_group.sh`
   - Assigns service principal and custom roles to specific resource groups
   - Shows before/after role assignment tables for verification

### Phase 3: Infrastructure Backend Setup

7. **Create Terraform State Storage Account**  
   _User Identity Required_  
   - `./scripts/unix/step7_create_tfstate_storage_account.sh`
   - Creates storage account and blob container for Terraform remote state
   - Fully idempotent with proper Azure Policy compliance

8. **Fix Terraform State Issues (Troubleshooting Utility)**  
   _As Needed_  
   - `./scripts/unix/step8_fix_terraform_state.sh`
   - Utility script for resolving state conflicts, 409 errors, and drift issues
   - Only run when experiencing Terraform state problems

### Phase 4: VM Access Setup

11. **Generate SSH Keys for VM Access**  
    _User Identity Required_  
    - `./scripts/unix/step11_create_ssh_key.sh`
    - Generates SSH key pair for Azure VM and Bastion access
    - Displays public key for GitHub secrets and terraform.tfvars

### Phase 5: Validation

12. **Run Validation Workflow**  
    - See `ValidationProcess.md` for end-to-end pipeline testing

## 🔧 Script Features and Best Practices

- **Idempotent Design**: All scripts can be safely re-run multiple times without adverse effects
- **Comprehensive Error Handling**: Scripts validate prerequisites and provide clear error messages
- **Incremental Progress**: Each script builds on the previous step's credentials file
- **Least Privilege Enforcement**: Only assigns minimum required permissions at appropriate scopes
- **Audit Trail**: Before/after comparisons for verification and compliance
- **BC Gov Policy Compliance**: Follows Azure landing zone requirements and naming conventions

## ⚠️ Important: Terraform Backend Prerequisites

Before running any Terraform pipeline, ensure these resources exist:

1. **Resource Groups**
   - **Script:** `./scripts/unix/step6_create_resource_group.sh`
   - Creates all required resource groups with proper tags and compliance
   - **GitHub Variables:** Resource group names are automatically added to GitHub secrets

2. **Custom Roles**
   - **Script:** `./scripts/unix/step6.1_CreateCustomRole.sh`
   - Creates custom Azure roles with minimal required permissions
   - Handles both creation and updates idempotently

3. **Role Assignments**
   - **Script:** `./scripts/unix/step6.2_assign_roles_to_resource_group.sh`
   - Assigns service principal to resource groups with appropriate roles
   - Shows before/after verification tables

4. **Terraform State Storage**
   - **Script:** `./scripts/unix/step7_create_tfstate_storage_account.sh`
   - Creates storage account and blob container for Terraform remote state
   - **GitHub Variables:** Automatically sets `TFSTATE_SA`, `TFSTATE_CONTAINER`, etc.

**Verification:**
All scripts provide before/after comparisons and verification steps. Check the output carefully and ensure all resources are created successfully before proceeding to Terraform deployment.

---

## Key Features & Improvements (July 2025)

- **Fully Automated**: All onboarding steps use robust, idempotent scripts
- **Resource Group Management**: Step6 scripts are restored and enhanced for complete automation
- **Custom Role Creation**: Automated creation and assignment of minimal-privilege custom roles
- **Enhanced Security**: Proper role scoping with subscription vs. resource group level assignments
- **Comprehensive Documentation**: Detailed inline comments and troubleshooting guides
- **SSH Key Management**: Automated SSH key generation for VM and Bastion access
- **Validation Tools**: Before/after comparisons and verification steps in all scripts
- **Error Recovery**: Troubleshooting utilities for state drift and common issues

---

## Directory Structure

```
RegisterApplicationInAzureAndOIDC/
├── README.md
├── TROUBLESHOOTING_GUIDE.md
├── SSH_KEY_REFERENCE.md
└── scripts/
    ├── unix/
    │   ├── step1_register_app.sh
    │   ├── step2_grant_subscription_level_permissions.sh
    │   ├── step3_configure_github_oidc_federation.sh
    │   ├── step4_prepare_github_secrets.sh
    │   ├── step5_add_github_secrets_cli.sh
    │   ├── step6_create_resource_group.sh
    │   ├── step6.1_CreateCustomRole.sh
    │   ├── step6.2_assign_roles_to_resource_group.sh
    │   ├── step7_create_tfstate_storage_account.sh
    │   ├── step8_fix_terraform_state.sh
    │   ├── step11_create_ssh_key.sh
    │   └── step12_import_existing_resources.sh
    └── ag-pssg-azure-files-poc-dev-resource-group-contributor.json
    └── ag-pssg-azure-files-poc-dev-role-assignment-writer.json
```

---

## Prerequisites

- Azure account with permissions to create app registrations, assign roles, and create resource groups
- Access to the GitHub repository with admin permissions for secrets management
- Local development environment with Azure CLI, Git, and Bash
- GitHub CLI (`gh`) installed for automated secret management (optional but recommended)

---

## Quick Start Summary

1. **Run all scripts in order** (steps 1-7, 6.1, 6.2, 11)
2. **Verify each step** using the before/after output provided by scripts
3. **Check troubleshooting guides** if any issues arise
4. **Proceed to Terraform validation** after all scripts complete successfully

For detailed troubleshooting and SSH key management, see the comprehensive guides linked at the top of this document.

---

## Why This Registration is Critical

- The service principal provides the identity that GitHub Actions uses to authenticate to Azure.
- All subsequent automation work depends on this identity.
- Terraform running in GitHub Actions cannot create its own service principal; it needs this pre-existing identity.
- Credentials (client ID, tenant ID, subscription ID) are stored as GitHub secrets and referenced in workflows.
- No long-lived secrets when using OIDC federation.

---

## BC Government OIDC Requirements

- OpenID Connect (OIDC) is the recommended authentication method
- Eliminates need for storing long-lived credentials
- Self-hosted runners required for Azure data storage access
- Stores only identity information (NOT secrets) as GitHub secrets:
  - AZURE_CLIENT_ID (application ID)
  - AZURE_TENANT_ID (tenant ID)
  - AZURE_SUBSCRIPTION_ID (subscription ID)

---

## OIDC Authentication Flow and Best Practices

- OpenID Connect (OIDC) federation enables secure, passwordless authentication between GitHub Actions and Azure
- Instead of storing long-lived secrets, you create a federated credential that establishes a trust relationship with GitHub
- This credential specifies which GitHub repository, branch, or environment is allowed to request tokens
- For accessing Azure data storage, self-hosted runners on Azure are required as public access is not supported

#### Authentication Process:
1. GitHub workflow requests OIDC token from GitHub
2. Token sent to Azure AD
3. Azure AD verifies token came from the trusted repository
4. If verified, Azure AD issues short-lived access token

#### How Authentication Works Without Traditional Secrets

> **Note: This is counter-intuitive but important to understand**

A common point of confusion is how this authentication works without requiring a traditional client secret or certificate. Here's a simplified explanation:

1. **Trust Relationship**: During the OIDC configuration, you establish a trust relationship between Azure AD and GitHub for a specific repository.
2. **GitHub's Role**: When a workflow runs, GitHub acts as an identity provider (IDP) and generates a cryptographically-signed token that proves the workflow's origin.
3. **Using the Three IDs**: Your workflow passes the three GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) to Azure AD, along with the GitHub-generated token.
4. **Azure AD Validation**: Azure AD uses these IDs to find the correct app registration, look up its federated credentials, verify the token, and confirm it's from the expected repo/branch.
5. **No Traditional Secret Needed**: The security comes from GitHub's ability to cryptographically prove the workflow's origin, combined with the pre-configured federated credentials in Azure AD.

This approach is more secure than traditional client secrets because:
- No long-lived secrets that can be leaked or need rotation
- Authentication is tied to the specific GitHub repository
- Immediate revocation by removing federated credentials in Azure AD

#### OIDC Authentication Flow Diagram

```mermaid
sequenceDiagram
    autonumber
    participant GHWorkflow as GitHub<br>Workflow
    participant GHToken as GitHub Token<br>Service
    participant AzLogin as azure/login<br>Action
    participant AzAD as Azure AD<br>(Microsoft Entra ID)
    participant AzResource as Azure<br>Resources
    Note over GHWorkflow,AzResource: One-time Setup
    GHWorkflow->>AzAD: Register federated credential
    AzAD-->>GHWorkflow: Credential registered successfully
    Note over GHWorkflow,AzResource: During Workflow Execution
    GHWorkflow->>GHToken: Request OIDC token
    GHToken-->>GHWorkflow: Return signed OIDC JWT
    GHWorkflow->>AzLogin: Pass OIDC token + 3 IDs
    AzLogin->>AzAD: Request access token
    Note right of AzAD: Validation Process
    AzAD-->>AzLogin: Issue short-lived Azure access token
    AzLogin-->>GHWorkflow: Configure Azure credential for session
    GHWorkflow->>AzResource: Access resources
    AzResource-->>GHWorkflow: Return resource data/confirm action
```

---

## Implementation Steps

---
### Phase 1: Service Principal and OIDC Setup (Steps 1-5)

These steps create the low-privilege identity for the GitHub Actions pipeline and configure the OIDC trust relationship.

#### Step 1: Register Application in Azure
Creates the Application Registration and its corresponding Service Principal.
*   **Unix/macOS:** `./scripts/unix/step1_register_app.sh`

#### Step 2: Grant Required Permissions to the Service Principal
Assigns a specific, limited set of roles to the Service Principal. These roles **do not** include permission to create resource groups.
*   **Unix/macOS:** `./scripts/unix/step2_grant_subscription_level_permissions.sh`

#### Step 3: Configure Federated Credentials (OIDC)
This step establishes the secure, passwordless trust between Azure and your GitHub repository.
*   **Unix/macOS:** `./scripts/unix/step3_configure_github_oidc_federation.sh`

##### In-Depth: OIDC Federated Credentials Overview
OpenID Connect (OIDC) federation enables secure, passwordless authentication between GitHub Actions and Azure. Instead of storing long-lived secrets, you create a federated credential in your Azure AD application that establishes a trust relationship with GitHub. This credential specifies which GitHub repository, branch, or environment is allowed to request tokens for your Azure app.

When a GitHub Actions workflow runs, it requests a special OIDC token from GitHub. Azure validates this token against the federated credential configuration. If the request matches the allowed repository and branch/environment, Azure issues a short-lived access token to the workflow. This allows GitHub Actions to authenticate to Azure securely, following best practices and reducing the risk of credential leaks.

**Key points:**
- Federated credentials are configured in Azure AD for your app registration.
- Each credential references your GitHub organization, repository, and optionally branch or environment.
- No secrets are stored in GitHub; authentication is handled dynamically via OIDC tokens.
- This approach is recommended for secure CI/CD pipelines and aligns with BC Government best practices.

For a detailed technical explanation, refer to [Introduction to Azure DevOps workload identity federation (OIDC) with Terraform](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/).


Federated credentials allow GitHub Actions to authenticate to Azure without storing secrets. This follows BC Government best practices for secure CI/CD implementation.

##### OIDC Federated Credentials Overview
OpenID Connect (OIDC) federation enables secure, passwordless authentication between GitHub Actions and Azure. Instead of storing long-lived secrets, you create a federated credential in your Azure AD application that establishes a trust relationship with GitHub. This credential specifies which GitHub repository, branch, or environment is allowed to request tokens for your Azure app.

When a GitHub Actions workflow runs, it requests a special OIDC token from GitHub. Azure validates this token against the federated credential configuration. If the request matches the allowed repository and branch/environment, Azure issues a short-lived access token to the workflow. This allows GitHub Actions to authenticate to Azure securely, following best practices and reducing the risk of credential leaks.

For an in-depth understanding of workload identity federation with OIDC, refer to [Introduction to Azure DevOps workload identity federation (OIDC) with Terraform](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/).

##### Key points:

- Federated credentials are configured in Azure AD for your app registration
- Each credential references your GitHub organization, repository, and optionally branch or environment
- No secrets are stored in GitHub; authentication is handled dynamically via OIDC tokens
- This approach is recommended for secure CI/CD pipelines and aligns with BC Government best practices

##### BC Government OIDC Best Practices and Guidelines

- OpenID Connect (OIDC) is the recommended authentication method for GitHub Actions to securely access Azure subscriptions
- This method eliminates the need for storing long-lived credentials as GitHub secrets
- For accessing Azure data storage and databases, self-hosted runners on Azure are required as public access is not supported
- Microsoft provides sample Terraform code for deploying these runners in the `azure-lz-samples` repository
- You store identity information (NOT secrets) as GitHub secrets
- The secrets include:
  - `AZURE_CLIENT_ID` (the application/client ID) 
  - `AZURE_TENANT_ID` (your Azure tenant ID) 
  - `AZURE_SUBSCRIPTION_ID` (your subscription ID)

##### Authentication Process:

- When a GitHub workflow runs, it requests a special OIDC token from GitHub
- This token is sent to Azure AD
- Azure AD verifies the token came from the trusted GitHub repository
- If verified, Azure AD issues a short-lived access token for Azure resources

Reference: [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions)


#### Step 4: Prepare GitHub Secrets
In this step, you will store the necessary credentials as GitHub secrets. These secrets will be used by GitHub Actions to authenticate to Azure.

Reads the credentials file and displays the exact values needed for GitHub repository secrets.
*   **Unix/macOS:** `./scripts/unix/step4_prepare_github_secrets.sh`
*   **Windows:** `.\scripts\windows\step4_prepare_github_secrets.ps1`

#### Step 5: Setup Repo Secrets in GitHub
Before proceeding with Azure authentication, you need to add the required GitHub repository secrets and varaibles that will be used by the workflow and terraform:

Securely adds the necessary secrets (`AZURE_CLIENT_ID`, etc.) to your GitHub repository for the pipeline to use. The automated script is the recommended method, but manual instructions are also provided.

*   **Recommended (Automated CLI):**
    *   **Unix/macOS:** `./scripts/unix/step5_add_github_secrets_cli.sh`
    *   **Windows:** `.\scripts\windows\step5_add_github_secrets_cli.ps1`

*   **Alternative (Manual):**
    1.  Obtain the values for `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` by running the `step4` script or by inspecting your `.env/azure-credentials.json` file.
    2.  Navigate to your GitHub repository's **Settings > Secrets and variables > Actions**.
    3.  Click **"New repository secret"** for each of the three secrets and paste the corresponding value.

---
### Phase 2: Foundational Resource Creation (Step 6)

This phase requires a user with high privileges (`Contributor` or `Owner`) to create the permanent "container" that the low-privilege pipeline will deploy into.

#### Step 6: Create the Permanent Resource Group (Manual, High-Privilege Step)

The pipeline's Service Principal cannot create resource groups. This is a deliberate security measure. Therefore, the permanent resource group for your project must be created once, manually, by a user with sufficient permissions.

**Prerequisite:** Ensure you are logged into Azure CLI (`az login`) with your personal user account that has `Contributor` or `Owner` permissions on the subscription.

**Action:** Run the `step6` script to create the resource group.

*   **Unix/macOS:**
    ```bash
    # Usage: ./script <resource-group-name> [location]
    ./scripts/unix/step6_create_resource_group.sh your-permanent-rg-name canadacentral
    ```
*   **Windows:**
    ```powershell
    # Usage: ./script -rgname <resource-group-name> [-location <location>]
    ./scripts/windows/step6_create_resource_group.ps1 -rgname your-permanent-rg-name -location canadacentral
    ```
*   **After running this script, you must update the `RESOURCE_GROUP_NAME` secret in your GitHub repository settings to match `your-permanent-rg-name`.**

This completes the foundational setup. The pipeline now has an identity and a place to deploy resources.

---
### Step 7: Validate Your Setup

Now that you have completed the full one-time setup process, proceed to the validation phase. This will confirm that the pipeline can use its identity to deploy resources into the resource group you created.

1.  Go to [ValidationProcess.md](../ValidationProcess.md).
2.  Follow the instructions to run the **`Terraform Validation Workflow`**.

## Progress Tracking

Use this table to track your progress through the steps.

| Step | Description | Status | Completed By | Date |
|:---|:---|:---|:---|:---|
| 1 | Register Application in Azure AD | Not Started | | |
| 2 | Grant Subscription-Level Permissions | Not Started | | |
| 3 | Configure OIDC Federation | Not Started | | |
| 4 | Prepare GitHub Secrets | Not Started | | |
| 5 | Add GitHub Secrets (Automated) | Not Started | | |
| 6 | Create Resource Groups | Not Started | | |
| 6.1 | Create Custom Roles | Not Started | | |
| 6.2 | Assign Roles to Resource Groups | Not Started | | |
| 7 | Create Terraform State Storage | Not Started | | |
| 8 | Test Terraform State (if needed) | Not Started | | |
| 11 | Generate SSH Keys for VM Access | Not Started | | |
| 12 | Run Validation Process | Not Started | | |

## Appendix

### A1: BC Government OIDC Guidelines
- OpenID Connect (OIDC) is the recommended authentication method for GitHub Actions to securely access Azure subscriptions.
- This method eliminates the need for storing long-lived credentials as GitHub secrets.
- For accessing Azure data storage and databases, self-hosted runners on Azure are required as public access is not supported.
- Microsoft provides sample Terraform code for deploying these runners in the `azure-lz-samples` repository.
- You store identity information (NOT secrets) as GitHub secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
- **Reference:** [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions)

### A2: OIDC Authentication Flow Diagram
```mermaid
sequenceDiagram
    autonumber
    participant GHWorkflow as GitHub<br>Workflow
    participant GHToken as GitHub Token<br>Service
    participant AzLogin as azure/login<br>Action
    participant AzAD as Azure AD<br>(Microsoft Entra ID)
    participant AzResource as Azure<br>Resources
    
    Note over GHWorkflow,AzResource: One-time Setup (This Guide)
    GHWorkflow->>AzAD: Register federated credential for a repo/branch
    AzAD-->>GHWorkflow: Credential registered successfully
    
    Note over GHWorkflow,AzResource: During Workflow Execution
    GHWorkflow->>GHToken: Request OIDC token
    GHToken-->>GHWorkflow: Return signed OIDC JWT
    
    GHWorkflow->>AzLogin: Pass OIDC token + 3 IDs (client, tenant, subscription)
    AzLogin->>AzAD: Request access token using OIDC token & IDs
    
    Note right of AzAD: Validation: <br>1. Find app using client-id<br>2. Check federated credentials<br>3. Verify token signature & subject
    
    AzAD-->>AzLogin: Issue short-lived Azure access token
    AzLogin-->>GHWorkflow: Configure Azure credential for session
    
    GHWorkflow->>AzResource: Access resources using temporary token
    AzResource-->>GHWorkflow: Return resource data/confirm action
```

### A3: Security Considerations

1. **Credential Management**:
   - Uses OIDC federation instead of client secrets
   - Credentials stored in `.env/azure-credentials.json` (git-ignored)
   - No long-lived secrets in GitHub
   - Consider using shorter-lived credentials for enhanced security
   - Regular credential rotation schedule should be established

2. **Access Control**:
   
#### Azure Roles for Azure Files PoC Architecture

   The following roles are mapped to specific components from our PoC architecture as detailed in [ArchitectureOverview.md](../ArchitectureOverview.md):

   | **Role** | **Applies To Architecture Components** | **Why It's Needed** | **Recommended Assignment Scope** |
   |----------|----------------------------------|---------------------|-------------------------------|
   | **Reader** | All Azure resources | Base role for viewing resources and their configurations | Subscription or Resource Group |
   | **Storage Account Contributor** | - Azure Files (Premium/Standard)<br>- Azure Storage Account<br>- Azure Blob Storage | Core role for creating and managing storage accounts | Subscription (if needed broadly) or Resource Group |
   | **[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor** | - Azure Virtual Network Subnets<br>- Subnet-level configurations | BC Gov landing zone custom role for managing Virtual Network subnets | Subscription or Resource Group (as required by landing zone) |
   | **Private DNS Zone Contributor** | - Private DNS Zone | For configuring name resolution for private endpoints | Resource Group or DNS Zone |
   | **Monitoring Contributor** | - Azure Monitor<br>- Log Analytics | For setting up diagnostic settings, metrics, and alerts | Resource Group |
   | **Storage Account Backup Contributor** | - Azure Storage Account<br>- Azure Backup | For performing backup and restore operations | Storage Account or Resource Group |
   | **Storage Blob Data Owner** | - Blob containers<br>- Blob data | Full access to blob data including POSIX ACL management | Storage Account or Resource Group |
   | **Storage File Data Privileged Contributor** | - File shares<br>- NTFS permissions | Advanced file share access with NTFS permission management | Storage Account or Resource Group |
   | **Storage File Data SMB Share Elevated Contributor** | - SMB shares<br>- NTFS permissions | Enhanced SMB share operations with permission modifications | Storage Account or Resource Group |
   | **Storage Blob Delegator** | - SAS tokens<br>- Blob access | For generating user delegation keys for blob access | Storage Account |
   | **Storage File Delegator** | - SAS tokens<br>- File access | For generating user delegation keys for file access | Storage Account |
   | **Storage Queue Data Contributor** | - Storage queues | For complete queue operations functionality | Storage Account or Resource Group |
   | **Storage Table Data Contributor** | - Storage tables | For complete table operations functionality | Storage Account or Resource Group |
   | **DNS Resolver Contributor** | - DNS resolution | For configuring DNS resolution in hybrid scenarios | Resource Group or DNS Zone |
   | **Azure Container Storage Contributor** | - Container operations | For potential container-based solutions | Storage Account or Resource Group |

#### Role Priority and Implementation

   - **Only essential roles are assigned at the subscription level.** Storage/data plane roles must be assigned at the storage account or resource group level for least privilege. See onboarding scripts for examples and comments.
   - For production: Consider restricting roles to specific resource groups
   - Regular review of assigned permissions recommended
   - For minimal permissions implementations:
     - The **Storage Account Contributor** and **[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor** roles are essential
     - Storage data plane roles (SMB Share, Queue, Table) provide granular access control
     - BC Gov landing zone custom roles should be preferred over generic equivalents
     - Additional roles can be added incrementally as needed
     - Follow the principle of least privilege
   
#### BC Government Landing Zone Specifics
   - The **[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor** role is a custom role specific to BC Gov's landing zone
   - It provides focused permissions for subnet management without broader network access
   - For broader network management (UDRs, NSGs, VPN, ExpressRoute), work with the Platform team
   - Resource group creation may require Platform team assistance or additional permissions

### A4: Role Verification Process
   
   **Via Azure Portal**:
   1. Navigate to Subscriptions > [Your Subscription]
   2. Access control (IAM) > Role assignments tab
   3. Verify all four role assignments for the service principal
   
   **Via Azure CLI**:
   ```bash
   az role assignment list --assignee $appRegistration --output table
   ```
   Verify output shows all roles with correct scope

3. **Monitoring and Auditing**:
   - Monitor service principal activity through Azure Activity Logs
   - Enable and review diagnostic settings for:
     - Authentication attempts
     - Role assignment changes
     - Resource access patterns
   - Set up alerts for suspicious activities
   - Regular security audit of service principal actions

### A5: Verify Setup

1. Run the Azure Login Test:
   - Navigate to GitHub Actions tab
   - Run the "Azure Login Test" workflow
   - Verify successful authentication

2. Validate End-to-End Pipeline:
   - Run the "Terraform Validation Workflow"
   - Use the `dev` environment
   - Enable cleanup to remove test resources
   - Verify successful:
     - Azure authentication via OIDC
     - Terraform initialization
     - Resource creation and cleanup

3. Begin Implementation:
   - Review the [Validation Process](../ValidationProcess.md)
   - Configure GitHub repository secrets
   - Begin Terraform automation implementation
   - Follow BC Government IaC best practices

### A6 Additional notes
- For security reasons, we're using OIDC federation rather than client secrets.
- This service principal is dedicated to the Azure Files PoC project only.
- The credentials from this registration process are used in multiple places:
- GitHub Actions workflows for direct Azure operations
- Terraform running in GitHub Actions for infrastructure deployment
- Any CI/CD pipelines that need to interact with Azure resources

### A7 References

- [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- [Azure DevOps OIDC Federation](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/)
- [Microsoft Identity Platform](https://docs.microsoft.com/en-us/azure/active-directory/develop/)

---

## Automated Role Assignment

Role assignment is now fully automated through the onboarding scripts:

- **Custom Role Creation**: `step6.1_CreateCustomRole.sh` handles creation and updates of custom roles
- **Role Assignment**: `step6.2_assign_roles_to_resource_group.sh` assigns all necessary roles to the service principal

These scripts provide before/after comparisons and handle all the complex role assignment logic automatically. Manual role assignment commands are no longer required.