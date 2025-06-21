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

## Configuration

1. Review and update `terraform.tfvars` with your specific values
2. For sensitive values that shouldn't be in version control, create a `secrets.tfvars` file (it's in .gitignore)

---

## Deployment Steps

> **REMINDER: Never deploy resources without explicit consent and review**

1. Initialize Terraform:
   ```bash
   terraform init
   ```
2. Plan your deployment (safe, creates no resources):
   ```bash
   terraform plan -out=tfplan
   ```
3. Review the plan output thoroughly with stakeholders.
4. Apply the deployment (REQUIRES EXPLICIT APPROVAL):
   ```bash
   terraform apply tfplan
   ```

---

## Cleanup

To destroy all resources created by this Terraform configuration:
```bash
terraform destroy
```

---

## Security Notes

- Never commit secrets to the repository
- Use Workload Identity Federation for CI/CD authentication
- The `terraform.tfvars` file should only contain non-sensitive configuration values
- Create a `secrets.tfvars` file for sensitive values and add it to `.gitignore`
- When using sensitive values in Terraform, use the `-var-file=secrets.tfvars` parameter
- For BC Government security requirements and best practices, refer to:
  - [Terraform Resources - BC Government Specific Requirements](../Resources/TerraformResourcesForAzurePoC.md#important-considerations-for-bc-government-azure-landing-zones)
  - [GitHub Actions Security](../Resources/GitHubActionsResourcesForAzureFilesPoC.md#bc-government-requirements)
  - [Azure Pipelines Security](../Resources/AzurePipelinesResources.md#security-considerations)

---

## Resources Created

This Terraform configuration creates:

1. Resource Group
2. Storage Account for Azure Files
3. Azure File Share
4. Virtual Network and Subnet with Service Endpoints
5. Network rules for the storage account

---

## Development & Validation Workflow Diagram

```mermaid
flowchart TD
    A[Onboarding & OIDC Setup] --> B[Local Validation (Azure CLI & Terraform)]
    B --> C{Validation Successful?}
    C -- No --> B
    C -- Yes --> D[Push to GitHub]
    D --> E[GitHub Actions Workflow]
    E --> F[OIDC Auth & Terraform Plan/Apply]
    F --> G[Azure Resource Deployment]
```
