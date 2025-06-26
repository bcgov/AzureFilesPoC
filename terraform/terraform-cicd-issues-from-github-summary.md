# Summary: Troubleshooting 403 Errors When Creating Azure File Shares via GitHub Actions CI/CD with Terraform

## Initial Problem:
Consistently receiving `403 This request is not authorized to perform this operation.` errors when attempting to create an `azurerm_storage_share` resource (a **data plane** operation) within an Azure Storage Account using a Terraform script deployed via a GitHub Actions CI/CD pipeline. This occurred despite the Service Principal (SPN) used by GitHub Actions appearing to have sufficient permissions for **control plane** operations (managing the storage account resource itself).

## Initial Assumption:
The problem was likely due to insufficient Azure RBAC (Role-Based Access Control) permissions (e.g., missing "Contributor" type roles for data plane access) or restrictive Azure Policies impacting the SPYes, absolutelyN's ability to act on the data plane.

## Key Distinction: Control Plane vs. Data Plane Operations
A. Here's your excellent summary augmented with the Control Plane vs. Data Plane analysis integrated critical factor in this troubleshooting is the difference between:
*   **Control Plane Operations:** Actions managing Azure resources themselves (e.g into the "Current State of Understanding" and "Key Learnings" sections.

```markdown
# Summary: Troubleshooting 403 Errors When Creating Azure File Shares via GitHub Actions CI/CD with Terraform

## Initial Problem:
Consistently., creating/modifying the storage account, role assignments via Azure Resource Manager - ARM). Your SPN largely succeeded here receiving `403 This request is not authorized to perform this operation.` errors when attempting to create an `azur after initial permission fixes.
*   **Data Plane Operations:** Actions interacting with data *inside* a resource (e.erm_storage_share` resource (a data plane operation) within an Azure Storage Account using a Terraform script deployed via a GitHub Actions CI/CD pipeline. This occurred despite the Service Principal (SPN) used by GitHub Actions appearing tog., creating/deleting file shares, reading/writing files via the File Service endpoint like `youraccount.file.core. have sufficient permissions and control plane operations (like managing the storage account resource itself) generally succeeding.

## Initial Assumption:
The problem was likely due to insufficient Azure RBAC (Role-Based Access Control) permissions (e.g., missing "Contributor"windows.net`). The `403` error specifically occurs during these operations.
Data plane access is subject to Azure type roles for data plane access) or restrictive Azure Policies impacting the SPN's ability to act on the data plane.

## RBAC for data actions, storage account network settings (firewall, public access), Azure Policy, and Azure AD Conditional Access Policies Troubleshooting Journey & Key Learnings:

1.  **Terraform Code & Module Structure:**
    *   **Learned:** Initial errors indicated problems with module structure (legacy provider blocks conflicting with `depends_on`) and mismatches, often with stricter scrutiny than control plane access.

## Troubleshooting Journey & Key Learnings:

1.  **Terra between variables passed to modules and those defined within them.
    *   **Resolution:** Refactored modules to removeform Code & Module Structure:**
    *   **Learned:** Initial errors indicated problems with module structure (legacy provider internal provider blocks, corrected variable definitions, and ensured proper passing of arguments.

2.  **Azure RBAC Permissions blocks conflicting with `depends_on`) and mismatches between variables passed to modules and those defined within them.
     for the Service Principal:**
    *   **Tried:**
        *   Ensured the SPN had `Storage*   **Resolution:** Refactored modules to remove internal provider blocks, corrected variable definitions, and ensured proper passing of Account Contributor` on the storage account (which grants both control and data plane permissions).
        *   Created and assigned arguments.

2.  **Azure RBAC Permissions for the Service Principal:**
    *   **Tried:**
 a custom role (`ag-pssg-azure-poc-role-assignment-writer`) with `Microsoft.Authorization        *   Ensured the SPN had `Storage Account Contributor` (which grants both control and data plane permissions at/roleAssignments/read, write, delete` permissions for managing control plane role assignments.
    *   **Lear a high level).
        *   Created and assigned a custom role (`ag-pssg-azure-poc-rolened:** The SPN (`ag-pssg-azure-files-poc-ServicePrincipal`) was significantly over-privileged.-assignment-writer`) with `Microsoft.Authorization/roleAssignments/read, write, delete` permissions for control plane role management.
    *   **Learned:** The SPN (`ag-pssg-azure-files-poc **The 403 error during file share creation (a data plane operation) was NOT due to a lack of-ServicePrincipal`) was, in fact, significantly over-privileged. **The 403 error during file share creation ( Azure RBAC permissions on the storage account itself.** Control plane operations related to RBAC were also eventually resolved.

**(data plane) was NOT due to a lack of Azure RBAC permissions on the storage account resource itself.**

3.  **Terra.  **Terraform State Management:**
    *   **Tried:** Encountered errors related to Terraform managing role assignments (form State Management:**
    *   **Tried:** Encountered errors related to Terraform trying to delete or create role assignments (control plane resources).
    *   **Learned:** The importance of granting the SPN permissions to `delete` role assignmentscontrol plane resources) that conflicted with existing Azure state.
    *   **Learned:** The importance of SPN permissions for managing and using `terraform import` for existing resources.
    *   **Resolution:** Successfully resolved state conflicts for control plane role role assignments and using `terraform import` to synchronize state.
    *   **Resolution:** Updated the custom role and successfully assignments.

4.  **Azure IAM Propagation Delays:**
    *   **Tried:** Introduced `time_ imported existing role assignments, stabilizing control plane operations.

4.  **Azure IAM Propagation Delays:**
    *   sleep` resources.
    *   **Learned:** While good practice for RBAC (control plane) propagation, this did not**Tried:** Introduced `time_sleep` resources.
    *   **Learned:** While good practice for RB resolve the core `403` error for the data plane file share creation.

5.  **Network Configuration of theAC assignment effectiveness, this did not resolve the core `403` error for the data plane file share creation. Storage Account & GitHub Runner:**
    *   **Initial State:** Storage account configured with `public_network_access_enabled =

5.  **Network Configuration of the Storage Account & GitHub Runner:**
    *   **Initial State:** Storage false`.
    *   **Tried - Runner IP Whitelisting:** Setting `public_network_access_enabled account `public_network_access_enabled = false`.
    *   **Tried - Runner IP Whitelisting = true` with dynamic IP rules.
        *   **Learned:** Still resulted in a `403`:** With `public_network_access_enabled = true` and dynamic IP firewall rules.
        *   ** for the data plane file share creation.
    *   **Tried - Trusted Azure Services Bypass:** With `public_networkLearned:** Still resulted in a `403` for file share creation, suggesting this wasn't a simple_access_enabled = false` and `network_rules.bypass = ["AzureServices"]`.
        *    firewall rule efficacy issue for the data plane.
    *   **Tried - Trusted Azure Services Bypass:** With `public_network**Learned:** Did not allow the data plane file share creation.
    *   **Tried - Fully Public Storage Account (Manual_access_enabled = false` and `network_rules.bypass = ["AzureServices"]`.
        *    Portal Change):** Set "Public network access" to "Enabled from all networks".
        *   **Learned (**Learned:** Insufficient for this data plane operation from a GitHub runner.
    *   **Tried - Fully Public StorageCrucial):** Even with the storage account's network wide open, the pipeline *still* failed with the same `4 Account (Manual Portal Change):**
        *   **Learned (Crucial):** Even with the storage account'03` error when trying the data plane operation of creating the file share. This was a pivotal learning point, indicatings network wide open, the pipeline *still* failed with the same `403` when trying to create the the block was not a simple storage firewall issue.

## Current State of Understanding: The Control Plane vs. Data Plane Distinction

The file share (data plane operation). This was a pivotal finding.

### Key Distinction: Control Plane vs. Data Plane Operations

A critical factor in understanding this troubleshooting journey is the difference between how Azure handles Control Plane and Data Plane operations:

**1. Control Plane Operations:**

*   **What they are:** Actions that manage Azure resources themselves. This includes creating, deleting, or modifying the configuration of resources like storage accounts, virtual machines, virtual networks, role assignments, etc.
*   **How they're managed:** Primarily through Azure Resource Manager (ARM). When Terraform runs `azurerm_storage_account` or `azurerm_role_assignment`, it's making ARM API calls to the `management.azure.com` endpoint.
*   **Authentication/Authorization:**
    *   Authentication is typically against Azure Active Directory (Azure AD).
    *   Authorization is primarily governed by Azure RBAC (Role-Based Access Control) roles assigned on the resource or its scope (e.g., `Storage Account Contributor`, `Owner`, your custom role `ag-pssg-azure-poc-role-assignment-writer`).
*   **Your Successes (Eventually):** Your pipeline is generally succeeding with control plane operations:
    *   It can plan and apply changes to the `azurerm_storage_account` resource (like modifying its network settings, even if that later caused issues for data plane access).
    *   It can now manage `azurerm_role_assignment` resources after the Service Principal was granted the necessary permissions (including `delete`) and existing assignments were imported into Terraform state.

**2. Data Plane Operations:**

*   **What they are:** Actions that interact with the data *inside* an Azure resource.
    *   **For Azure Storage:** This includes creating/deleting/reading/writing blobs, **creating/deleting/reading/writing files and file shares** (your specific issue), managing queues, and interacting with tables.
*   **How they're managed:** Through APIs specific to that Azure service's data plane endpoint. When Terraform runs `azurerm_storage_share`, it's making API calls directly to the Azure File Service endpoint (e.g., `stagpssgazurepocdev01.file.core.windows.net`).
*   **Authentication/Authorization (More Complex Layer):**
    *   **Authentication:** Still involves Azure AD for token-based authentication, which your Service Principal uses.
    *   **Authorization:** This is where multiple layers of security apply and is likely the source of your issue:
        *   **Azure RBAC for Data Operations:** Azure Storage supports using Azure RBAC roles for data plane authorization (e.g., `Storage File Data SMB Share Contributor`, `Storage Blob Data Contributor`). Your Service Principal possesses roles like `Storage Account Contributor` which implicitly grant these data plane permissions.
        *   **Network Access (Storage Firewall & Public Access Setting):** This is critical. The storage account's firewall rules (`network_rules`) and the `publicNetworkAccessEnabled` setting directly control whether the data plane endpoint (`youraccount.file.core.windows.net`) is even reachable from the requesting IP.
        *   **Azure AD Conditional Access Policies (CAP):** CAPs can specifically target attempts to access data plane APIs for services like Azure Storage. They scrutinize the identity (your SPN), its sign-in location (GitHub runner's public IP), the application being accessed (Azure Storage data plane), and can block the request if conditions aren't met. This can happen *even if* Azure RBAC on the resource is correct and the storage account's network settings "appear" to allow access.
        *   **Azure Policies (Data Plane Focused):** Azure Policy can also enforce rules specifically on data plane access (e.g., "data plane access only allowed via private link," or "deny data plane access from non-compliant identities/networks").

**Why the Distinction Matters for Your `403` Error:**

*   **Different Endpoints, Different Rules, Different Policy Enforcement:** Your Terraform `apply` communicates with two distinct "parts" of Azure. Control plane calls go to `management.azure.com`. The file share creation call (a data plane operation) goes directly to `stagpssgazurepocdev01.file.core.windows.net`. These endpoints can be subject to different network paths, firewall rules, and, crucially, different evaluations by Azure Policy and Conditional Access Policies.
*   **Higher Scrutiny on Data Plane Access:** Accessing or modifying the data within a service is often subject to stricter and more granular security controls than simply managing the existence or configuration of the resource shell (the control plane).
*   **The Error `checking for existing File Share ... 403`:** This error message explicitly comes from an attempt by Terraform to interact with the **data plane** of the Azure File Service. Before creating a file share, Terraform typically checks if a share with that name already exists. This "check" is itself a data plane read operation against the file service endpoint. The `403` indicates this data plane interaction is being denied.


## Current State of Understanding:
The persistent `403 persistent `403` error occurs specifically during the **data plane operation** of "checking for existing File Share" (API` error during the data plane operation (file share creation), even when the storage account's network is configured to be call to `youraccount.file.core.windows.net`), even when:
*   The SPN has ample publicly accessible and the SPN has ample Azure RBAC permissions, indicates that the problem is not a simple network firewall misconfiguration on Azure RBAC permissions (which cover both control and data plane actions for Storage).
*   The storage account's the storage account itself, nor a deficiency in resource-level RBAC.

The error `"This request is not authorized network is configured to be publicly accessible.

This strongly suggests the issue is not a direct network block *on the storage to perform this operation."` occurring during the `checking for existing File Share` step (a data plane API call to account's data plane endpoint itself* in the traditional firewall sense, nor a simple RBAC permission deficiency for data actions `youraccount.file.core.windows.net`) strongly suggests that **higher-level Azure governance or security mechanisms. Instead, the control preventing this specific data plane access is likely being enforced by higher-level Azure governance or security mechanisms are blocking the SPN's data plane request.** The most probable causes are:

1.  **Azure Policy Intervention:** that scrutinize the identity and context of data plane requests more stringently than control plane requests.

**Probable Root A high-priority Azure Policy with a "Deny" effect might be specifically blocking storage data plane operations from public IPs Causes (acting on the Data Plane interaction):**

1.  **Azure Policy Intervention:** A high-priority Azure Policy with a, by certain identity types (like SPNs under specific conditions), or enforcing that all data plane access must use private links "Deny" effect might be specifically blocking **data plane operations** on storage accounts from public IPs, by certain types of identities, regardless of the storage account's own network settings or RBAC.
2.  **Conditional Access Policy (CAP):** An Azure AD Conditional Access Policy is likely targeting the Service Principal and blocking its attempt to authenticate or use a token for (like SPNs), or if specific conditions (e.g., lack of private link) aren't met. the Azure Storage data plane API. This block could be based on location (public IP of the runner), the application being accessed ( This policy would override the storage account's own network settings for these data plane calls.
2.  **Conditional AccessAzure Storage data plane), or other defined conditions.
3.  **Service Principal Restrictions or API Permissions in Azure AD Policy (CAP):** An Azure AD Conditional Access Policy is likely targeting the Service Principal when it attempts to authenticate or obtain a token:** Although RBAC on the resource is correct, there might be underlying Azure AD configurations or limitations on how this specific SPN can for **Azure Storage data plane access**. CAPs can block this based on location (public GitHub runner IP), the application (Azure acquire tokens for or interact with the storage data plane.

**The issue has transitioned from suspected Azure RBAC or basic Storage data services), or the non-interactive nature of the SPN sign-in, even if control plane authentication was successful.
3.  **Service Principal Restrictions or Specific Token Issuance Policies in Azure AD for Data Plane:** While RBAC is sufficient network configuration problems to likely enforcement by more advanced security layers (Azure Policy, Conditional Access) specifically affecting the Service Principal's ability to perform data plane operations.**


## Remaining Options & Path Forward:

in logs for the Service Principal** (`ag-pssg-azure-files-poc-ServicePrincipal`) around the time of pipeline failure. The "Conditional Access" tab in a failed sign-in log is key.


### 🔍 Check Azure Policy Assignments
- Use `az policy assignment list` and `az policy state list` to inspect active policies.
- Look for policies with `Deny` effects on storage or network access.

1.  **Check1.  **Investigate Azure Policy (Focus on Data Plane Restrictions):**
    *   Examine Azure Policy assignments for " Azure AD Application Registration API Permissions (Lower Priority):**
    *   Go to **Azure Active Directory -> App registrationsDeny" effects related to Storage Account **data access**, not just general networking or resource management.
    *   Check Activity Log -> Your App (`ag-pssg-azure-files-poc-ServicePrincipal`) -> API permissions**.
     and Policy compliance for the storage account for data plane related blocks.

2.  **Investigate Conditional Access Policies** (Verify if any specific Azure Storage data plane or Microsoft Graph permissions are unexpectedly required or misconfigured.)

3.  **SelfCAP) (Focus on Storage Data Plane Access):**
    *   Review CAPs targeting "All cloud apps"-Hosted GitHub Actions Runner with Private Endpoints (The Most Robust Long-Term Solution):**
    *   Bypasses complexities of public network access and how CAP/Azure Policy treat public IP requests for data plane operations.
    *    or "Azure Storage" (specifically its data plane component if distinguishable).
    *   **Critically examine Azure AD Sign-inEnsures traffic is private and trusted.


### 🔐 Review Conditional Access Logs
- Go to **Azure AD → Sign-in logs**.
- Filter by the SPN and check the **Conditional Access** tab for failures.

**Check Azure AD Application RegistrationShare this summary.** They have visibility into organizational Azure Policies and Conditional Access Policies and can provide definitive answers or assist with exceptions.


### 🔄 Try OIDC Authentication
- Replace SPN with GitHub OIDC federation.
- This often bypasses CAPs that target legacy SPN flows.

### 🏗️ Consider a Self-Hosted Runner
- Deploy inside your Azure VNet.
- Use Private Endpoints for the storage account.
- This ensures trusted network access and avoids public IP issues.

### 🤝 Engage Platform Security Teams
- Especially if you're in a managed environment like BC Gov, they can confirm or exempt policies.
*    logs for the Service Principal** (`ag-pssg-azure-files-poc-ServicePrincipal`) for the *specific failed data plane access attempt*. The "Conditional Access" tab is key.

The current evidence strongly points towards these higher-level Azure AD or Azure Policy enforcement mechanisms as the root cause of the data plane ` API Permissions (Lower Likelihood for this specific SPN/RBAC scenario but a check):**
    *   Review403` error.

> **BC Gov Policy Note:**
> [Self-hosted runners on Azure are required to access data storage and database services from GitHub Actions. Public access to these services is not supported.](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
>
> _Source: BC Gov Public Cloud Technical Documentation – IaC and CI/CD, May 2025_