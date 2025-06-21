# Azure Files PoC Terraform Configuration

> **❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗**
>
> Always review configuration thoroughly and receive explicit approval before running `terraform apply`

## Getting Started: Onboarding, Validation, and Development Workflow

Before using any Terraform code in this project, you must complete the onboarding and OIDC setup steps. This ensures secure, auditable, and BC Gov-compliant automation.

### 1. Complete One-Time Onboarding & OIDC Setup
- Follow the step-by-step onboarding process in [`OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md`](../OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md).
- Run the modular onboarding scripts (Unix or Windows) to register the Azure AD application, configure OIDC, and set up credentials.
- Update and verify your `.env/azure-credentials.json` file as instructed.

### 2. Validate Your Setup
- Use the scripts in [`terraform/validation/localhost/`](./validation/localhost/) to validate Azure authentication and Terraform functionality locally.
- See [`validation/localhost/README.md`](./validation/localhost/README.md) for detailed instructions.
- Only proceed when all local validation steps pass.

### 3. Push to GitHub & Validate CI/CD
- After successful local validation, push your changes to GitHub.
- Use the workflows in [`terraform/validation/github/`](./validation/github/) to validate and deploy using OIDC authentication in GitHub Actions.
- See [`validation/github/README.md`](./validation/github/README.md) for details.

### 4. Develop, Test, and Deploy Infrastructure
- Use the modular structure below to develop and test Terraform code.
- **a. Localhost:** Validate and debug all changes locally using the scripts in [`validation/localhost/`](./validation/localhost/) before pushing.
- **b. GitHub Actions:** After successful local validation, push your changes and validate/deploy using the workflows in [`validation/github/`](./validation/github/).
- All changes should be validated locally and in CI/CD before production deployment.

---

## Directory Structure

```
terraform/
├── environments/           # Environment-specific configurations
│   ├── dev/              # Development environment
│   │   ├── main.tf       # Main configuration file
│   │   ├── variables.tf  # Input variables
│   │   └── terraform.tfvars # Dev-specific values
│   ├── test/             # Test environment
│   └── prod/             # Production environment
├── modules/              # Reusable modules
│   ├── networking/       # Network resource modules
│   │   ├── vnet/        # Virtual Network configuration
│   │   ├── subnet/      # BC Gov compliant subnet with NSG
│   │   └── private-endpoint/ # Private endpoint configuration
│   ├── storage/         # Storage resource modules
│   │   ├── account/     # Storage account configuration
│   │   ├── file-share/  # Azure Files configuration
│   │   └── blob/        # Blob storage with lifecycle
│   ├── security/        # Security resource modules
│   │   ├── nsg/         # Network Security Groups
│   │   └── firewall/    # Azure Firewall configuration
│   └── dns/             # DNS resource modules
│       ├── private-dns/ # Private DNS zones
│       └── resolver/    # DNS resolver configuration
├── validation/          # Validation scripts and process
│   ├── localhost/       # Local validation scripts and docs
│   │   ├── validate_authentication.sh   # Validates Azure CLI/OIDC authentication locally
│   │   ├── validate_terraform.sh        # Runs Terraform plan/apply locally using Azure CLI credentials
│   │   └── README.md                    # Local validation instructions and troubleshooting
│   └── github/          # GitHub Actions validation workflows and docs
│       ├── README.md                    # Instructions for CI/CD validation
│       └── (workflow YAMLs)             # GitHub Actions workflow files for OIDC and Terraform validation
└── README.md            # This file
```

---

## Key Reference Documentation

- [Onboarding & OIDC Setup Guide](../OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md)
- [Validation Process](../OneTimeActivities/ValidationProcess.md)
- [Terraform Resources for Azure Files PoC](../Resources/TerraformResourcesForAzurePoC.md)
- [Terraform with GitHub Actions Process](../Resources/TerraformWithGithubActionsProcess.md)
- [GitHub Actions Resources](../Resources/GitHubActionsResourcesForAzureFilesPoC.md)
- [Azure Pipelines Resources](../Resources/AzurePipelinesResources.md)
- [Azure Resource Naming Conventions](../Resources/AzureResourceNamingConventions.md) - Standard naming patterns for all Azure resource types used in this project

---

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or newer)
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (latest version recommended)
3. Access to Azure subscription
4. Onboarding and OIDC setup completed (see above)

---

## Authentication & Validation Methods

### Method 1: Localhost Validation (Recommended for development)

- Authenticate with Azure CLI:
  ```bash
  az login
  az account set --subscription "<your-Azure-subscription-ID>"
  ./validation/localhost/validate_authentication.sh
  ./validation/localhost/validate_terraform.sh
  ```
- See [`validation/localhost/README.md`](./validation/localhost/README.md) for details.

### Method 2: GitHub Actions Validation (For CI/CD)

- Push changes to GitHub and use workflows in [`validation/github/`](./validation/github/) for OIDC-based validation and deployment.
- See [`validation/github/README.md`](./validation/github/README.md) for details.

---

## Setup: Create and Populate Your terraform.tfvars File (Automated)

After running the inventory script for your platform (see below), a file `.env/azure_full_inventory.json` will be created containing a comprehensive inventory of your Azure resources.

**Recommended: Automatically populate your tfvars files using the provided automation scripts:**

- **Unix/macOS (Bash):**
  ```bash
  /OneTimeActivities/GetAzureExistingResources/unix/PopulateTfvarsFromDiscoveredResources.sh
  ```
- **Windows (PowerShell):**
  ```powershell
  .\OneTimeActivities\GetAzureExistingResources\windows\PopulateTfvarsFromDiscoveredResources.ps1
  ```

These scripts will read `.env/azure_full_inventory.json` and `.env/azure-credentials.json`, and automatically generate or update `terraform.tfvars` and `secrets.tfvars` with the correct values. This is the recommended, robust, and cross-platform approach.

**Manual method (not recommended):**
1. Copy `terraform.tfvars.template` to `terraform.tfvars`.
2. Fill in the variable values using the data from `.env/azure_full_inventory.json` (see onboarding/automation documentation for mapping details).
3. Do NOT include secrets or sensitive values in this file.
4. Ensure `terraform.tfvars` is listed in `.gitignore`.

This ensures your Terraform configuration references the correct, pre-existing Azure resources and keeps sensitive data out of version control.
