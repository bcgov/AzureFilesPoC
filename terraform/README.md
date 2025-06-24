# Azure Files PoC Terraform Configuration

> **❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗**
>
> Always review configuration thoroughly and receive explicit approval before running `terraform apply` on production-related environments.

## Getting Started: The Project Workflow

This project follows a structured, validation-first workflow. Before developing any infrastructure, you must complete the onboarding and validation steps to ensure the entire system is configured correctly.

### Step 1: Complete One-Time Onboarding & OIDC Setup
This is the foundational step to connect GitHub and Azure securely.
- **Follow the step-by-step process in [`OneTimeActivities/RegisterApplicationInAzureAndOIDCInGithub.md`](../OneTimeActivities/RegisterApplicationInAzureAndOIDCInGithub.md).**
- This will configure the Azure AD application, the OIDC federated credential, and the necessary GitHub secrets for secure, passwordless authentication.
- **You must manually create the required Azure resource group as a one-time onboarding activity,** using the provided onboarding script (`step6_create_resource_group.sh` or its Windows equivalent). This is required because BC Government policy restricts resource group creation via Terraform when using OIDC.
- Reference the created resource group in your Terraform variables and module calls. Do not attempt to manage resource groups with Terraform in this project.
- For more details and troubleshooting, see the onboarding README and the [Validation Process](../OneTimeActivities/ValidationProcess.md).

> **Policy Note:**
> BC Government IaC/CI/CD policy requires that resource groups be created outside of Terraform when using OIDC. This ensures proper separation of duties and aligns with security best practices. See the onboarding documentation for rationale and links to official guidance.

### Step 2: Validate Your Setup Locally
Before testing the automated pipeline, verify your setup from your local machine.
- This ensures your Azure CLI, Terraform CLI, and local variables are all correct.
- See the detailed guide in [`validation/localhost/README.md`](./validation/localhost/README.md) for instructions on using the helper scripts.
- **Only proceed when all local validation steps pass.**

### Step 3: Validate the CI/CD Pipeline
This step confirms that the GitHub Actions workflow can authenticate and deploy resources.
- Make a small, safe change inside the `terraform/validation/` directory (e.g., add a comment to `main.tf`).
- **Commit and push** this change to the `main` branch.
- This will trigger the `azure-terraform-validation.yml` workflow, which will perform a full `plan` and `apply` of the test resources.
- A successful run of this workflow validates the entire end-to-end automation process.

### Step 4: Develop Real Infrastructure using Modules
Once the validation pipeline succeeds, you are ready to build the actual infrastructure for the Proof of Concept.
- Development shifts from the `validation` folder to the `environments/dev/` folder.
- Instead of writing `resource` blocks directly, you will **call reusable modules** from the `modules/` directory to compose your environment.
- This modular approach ensures consistency, reusability, and adherence to best practices.

---

## Directory Structure

This project uses a modular, service-oriented structure. Only key directories and files are shown below for clarity:

```
terraform/
├── environments/           # Environment-specific configurations (dev, prod, test)
│   └── dev/                # Example: main.tf, outputs.tf, variables.tf, terraform.tfvars
│   └── test/
│   └── prod/
├── modules/                    # Reusable infrastructure modules (dns, networking, security, storage, etc.)
│   ├── automation/             # Automation helpers (e.g., AzCopy)
│   │   └── azcopy/             # AzCopy automation module
│   ├── dns/                    # DNS zones and resolvers
│   │   ├── private-dns/        # Private DNS zone module
│   │   └── resolver/           # DNS resolver module
│   ├── identity/               # Azure AD and managed identities
│   │   ├── aad/                # Azure Active Directory app registration
│   │   └── managed-identity/   # Managed Identity module
│   ├── keyvault/               # Azure Key Vault module
│   ├── monitoring/             # Monitoring and logging
│   │   └── log-analytics/      # Log Analytics workspace
│   ├── networking/             # Virtual networks and related resources
│   │   ├── private-endpoint/   # Private Endpoint module
│   │   ├── subnet/             # Subnet module
│   │   └── vnet/               # Virtual Network module
│   ├── policies/               # Policy assignments and definitions
│   ├── rbac/                   # Role-Based Access Control assignments
│   ├── security/               # Network security modules
│   │   ├── firewall/           # Azure Firewall module
│   │   └── nsg/                # Network Security Group module
│   ├── storage/                # Storage account and related modules
│   │   ├── account/            # Storage Account module
│   │   ├── blob/               # Blob Storage module
│   │   ├── file-share/         # File Share module (see files below)
│   │   │   ├── main.tf
│   │   │   ├── outputs.tf
│   │   │   └── variables.tf
│   │   ├── lifecycle/          # Storage lifecycle management
│   │   ├── object-replication/ # Object Replication module
│   │   └── private-link-service/# Private Link Service module
│   ├── tags/                   # Tagging strategy module
│   └── vm/                     # Virtual Machine module
├── validation/             # Validation environment for onboarding and pipeline tests
│   ├── localhost/          # Local validation scripts and README
│   ├── main.tf             # Validation Terraform config
│   ├── secrets.tfvars*     # Secrets for validation (never commit real secrets)
│   ├── terraform.tfvars*   # Variable values for validation
│   └── ...
```

> **Note:**
> - The `core/resource-group` module has been removed. Resource groups must be created manually as part of onboarding, not managed by Terraform.
> - See onboarding documentation for scripts and instructions to create resource groups and set up OIDC.

---

## Key Reference Documentation

- [Onboarding & OIDC Setup Guide](../OneTimeActivities/RegisterApplicationInAzureAndOIDCInGithub.md)
- [Validation Process](../OneTimeActivities/ValidationProcess.md)
- [Terraform with GitHub Actions Process](../Resources/TerraformWithGithubActionsProcess.md)
- [Azure Resource Naming Conventions](../Resources/AzureResourceNamingConventions.md)

---

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or newer)
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (latest version recommended)
3. Completion of the Onboarding and OIDC setup (see Step 1 above).

---

## How to Populate `terraform.tfvars` (For Local Development)

For local development, your Terraform commands will need a `terraform.tfvars` file.

**Recommended: Use the automation scripts to generate this file.**
- **Unix/macOS (Bash):**
  ```bash
  /OneTimeActivities/GetAzureExistingResources/unix/PopulateTfvarsFromDiscoveredResources.sh
  ```
- **Windows (PowerShell):**
  ```powershell
  .\OneTimeActivities\GetAzureExistingResources\windows\PopulateTfvarsFromDiscoveredResources.ps1
  ```

These scripts read your environment's discovered state and credentials to automatically generate the `terraform.tfvars` and `secrets.tfvars` files with the correct values. This is the recommended, robust approach.

---

> **Note:**
> Resource groups are NOT managed by Terraform in this project due to policy requirements. You must create the required resource group(s) manually as part of onboarding, using the script:
>
> `OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh`
>
> Reference this resource group in your Terraform variables and module calls.