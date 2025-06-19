# Azure Files PoC Terraform Configuration

> **❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗**
>
> Always review configuration thoroughly and receive explicit approval before running `terraform apply`

This directory contains Terraform configuration for deploying an Azure Files Proof of Concept (PoC) environment.

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

### Method 2: Environment Variables (For CI/CD or scripts)

Set these environment variables (don't store them in files that will be committed to Git):

```powershell
# PowerShell
$env:ARM_CLIENT_ID = "<service-principal-client-id>"
$env:ARM_CLIENT_SECRET = "<service-principal-client-secret>"
$env:ARM_SUBSCRIPTION_ID = "<azure-subscription-id>"
$env:ARM_TENANT_ID = "<azure-tenant-id>"
```

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

- Never commit secrets to the repository
- Use environment variables for authentication when possible
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

This project follows a staged approach to infrastructure development:

1. **Local Development First**: Develop and test all Terraform scripts locally before introducing any CI/CD automation
2. **Manual Validation**: Perform controlled testing with minimal resources
3. **GitHub Actions Integration**: Only after successful manual testing

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
