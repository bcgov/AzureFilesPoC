# Azure Files PoC Terraform Configuration

> **❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗**
>
> Always review configuration thoroughly and receive explicit approval before running `terraform apply` on production-related environments.

## Getting Started: The Project Workflow

This project follows a structured, validation-first workflow. Before developing any infrastructure, you must complete the onboarding and validation steps to ensure the entire system is configured correctly.

### Step 1: Complete One-Time Onboarding & OIDC Setup
This is the foundational step to connect GitHub and Azure securely.
- Follow the step-by-step process in [`OneTimeActivities/RegisterApplicationInAzureAndOIDCInGithub.md`](../OneTimeActivities/RegisterApplicationInAzureAndOIDCInGithub.md).
- This will configure the Azure AD application, the OIDC federated credential, and the necessary GitHub secrets.

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

```
terraform/
├── environments/           # Environment-specific configurations (e.g., dev, test, prod)
│   ├── dev/              # Main workspace for the Development environment.
│   │   ├── main.tf       # Composes modules to build the 'dev' environment.
│   │   └── ...
│   └── ...
├── modules/              # Reusable, standardized building blocks for Azure resources.
│   ├── networking/       # Modules for VNet, Subnet, Private Endpoint, etc.
│   ├── storage/          # Modules for Storage Account, File Share, etc.
│   └── ...
├── validation/           # A self-contained module to smoke test the CI/CD pipeline and auth.
│   ├── main.tf         # A simple, flat Terraform config for the test.
│   ├── localhost/        # Helper scripts and a detailed guide for local debugging.
│   └── README.md         # High-level documentation for the validation module.
└── README.md             # This file: the main entry point for the Terraform configuration.
```

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