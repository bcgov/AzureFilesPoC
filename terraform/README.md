# Azure Files PoC Terraform Configuration

> **❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗**
>
> Always review configuration thoroughly and receive explicit approval before running `terraform apply`

This directory contains Terraform configuration for deploying an Azure Files Proof of Concept (PoC) environment.

## Directory Structure

This project uses a modular Terraform structure to implement the Azure Files PoC architecture. Below is the high-level structure:

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
└── README.md            # This file
```

For detailed information about each module, including BC Government-specific requirements, implementation details, and usage examples, see:
- [Terraform Module Structure Documentation](../Resources/TerraformModuleStructure.md)

## Key Reference Documentation

Please review these important resources before proceeding:

- [Terraform Resources for Azure Files PoC](../Resources/TerraformResourcesForAzurePoC.md) - Detailed Terraform configurations and BC Government-specific requirements
- [Terraform with GitHub Actions Process](../Resources/TerraformWithGithubActionsProcess.md) - CI/CD integration with GitHub Actions
- [GitHub Actions Resources](../Resources/GitHubActionsResourcesForAzureFilesPoC.md) - GitHub Actions specific configuration and BC Government context
- [Azure Pipelines Resources](../Resources/AzurePipelinesResources.md) - Azure Pipelines integration and Workload Identity Federation

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or newer)
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (latest version recommended)
3. Access to Azure subscription

## Authentication

Before running Terraform, authenticate to Azure using one of these methods:

### Method 1: Azure CLI (Recommended for development)

```bash
az login
az account set --subscription "<your-Azure-subscription-ID>"
```

### Method 2: Workload Identity Federation (For CI/CD)

For GitHub Actions or Azure Pipelines, use Workload Identity Federation (OIDC) authentication. This is the recommended and required approach for BC Government implementations. See:
- [GitHub Actions OIDC setup](../Resources/GitHubActionsResourcesForAzureFilesPoC.md#github-actions-authentication)
- [Azure Pipelines OIDC setup](../Resources/AzurePipelinesResources.md#workload-identity-federation-oidc)

## Configuration

1. Review and update `terraform.tfvars` with your specific values
2. For sensitive values that shouldn't be in version control, create a `secrets.tfvars` file (it's in .gitignore)

## Deployment Steps

> **REMINDER: Never deploy resources without explicit consent and review**

Initialize Terraform:
```bash
terraform init
```

Plan your deployment (safe, creates no resources):
```bash
terraform plan -out=tfplan
```

Review the plan output thoroughly with stakeholders.

Apply the deployment (REQUIRES EXPLICIT APPROVAL):
```bash
# Only after explicit approval and review
terraform apply tfplan
```

## Cleanup

To destroy all resources created by this Terraform configuration:
```bash
terraform destroy
```

## Security Notes

For BC Government security requirements and best practices, refer to:
- [Terraform Resources - BC Government Specific Requirements](../Resources/TerraformResourcesForAzurePoC.md#important-considerations-for-bc-government-azure-landing-zones)
- [GitHub Actions Security](../Resources/GitHubActionsResourcesForAzureFilesPoC.md#bc-government-requirements)
- [Azure Pipelines Security](../Resources/AzurePipelinesResources.md#security-considerations)

Additional security requirements:
- Never commit secrets to the repository
- Use Workload Identity Federation for CI/CD authentication
- The `terraform.tfvars` file should only contain non-sensitive configuration values
- Create a `secrets.tfvars` file for sensitive values and add it to `.gitignore`
- When using sensitive values in Terraform, use the `-var-file=secrets.tfvars` parameter

## Resources Created

This Terraform configuration creates:

1. Resource Group
2. Storage Account for Azure Files
3. Azure File Share
4. Virtual Network and Subnet with Service Endpoints
5. Network rules for the storage account

## Development Workflow

This project follows BC Government's recommended approach to infrastructure development. For detailed process information, refer to:
- [Terraform with GitHub Actions Process](../Resources/TerraformWithGithubActionsProcess.md#implementation-guide)
- [Azure Pipelines Implementation](../Resources/AzurePipelinesResources.md#implementation-example)

Development stages:
1. **Local Development First**: Develop and test all Terraform scripts locally
2. **Manual Validation**: Perform controlled testing with minimal resources
3. **CI/CD Integration**: Implement using either:
   - GitHub Actions with self-hosted runners
   - Azure Pipelines with Workload Identity Federation

### Current Phase: Local Terraform Development

At this stage:
- Use Azure CLI authentication (`az login`) for local development
- Focus on writing and testing Terraform code without creating resources
- Use `terraform plan` extensively to validate configurations
- Document all configuration values and decision points
- Maintain all code in version control

### Benefits of Local-First Development

- **Simplified Authentication**: Azure CLI login rather than service principals
- **Direct Feedback**: Immediate error messages and troubleshooting
- **Incremental Development**: Build and test components one at a time
- **Focused Learning**: Master Terraform basics before adding CI/CD complexity
- **Better Documentation**: Document infrastructure as you develop it

### When to Move to GitHub Actions

Only introduce GitHub Actions automation when:
1. All Terraform scripts are fully developed and tested locally
2. The team has confidence in the infrastructure code
3. The Service Principal has been properly configured and tested
4. Workflows for approvals and security checks have been defined

For now, focus on developing the Terraform scripts locally and documenting the planned infrastructure.
