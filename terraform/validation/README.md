# Terraform Validation Module

## Purpose

This module provides a minimal Terraform configuration to validate the Azure authentication, permissions, and CI/CD workflow without creating significant resources or incurring costs. It's designed as a "smoke test" for your Terraform infrastructure-as-code setup.

> **Important**: This module is part of the validation process described in the comprehensive [ValidationProcess.md](/OneTimeActivities/ValidationProcess.md) guide. Please refer to that document for the full end-to-end validation process.

## Directory Structure

This validation module is organized into two key areas:

- **[localhost/](localhost/)** - Documentation and scripts for running validation locally
- **[github/](github/)** - Documentation for running validation through GitHub Actions

Both validation methods use the same underlying Terraform code but with different authentication mechanisms.

## What This Module Creates

- A resource group with appropriate tags
- A storage account with minimal configuration
- A private blob container
- A "Hello World" text blob

## Relationship to One-Time Activities

This validation module works in conjunction with the one-time setup activities described in:
- [RegisterApplicationInAzureAndOIDC](/OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md) - For Azure AD app registration and OIDC configuration
- [github-actions-setup.md](/OneTimeActivities/github-actions-setup.md) - For GitHub Actions setup documentation

The validation process verifies that those one-time activities were completed correctly by testing:
1. OIDC authentication from GitHub Actions to Azure
2. Service principal permissions to create Azure resources
3. Terraform's ability to create, modify, and delete resources

## How to Use

### Local Validation

To run this validation locally:

```shell
# Navigate to this directory
cd terraform/validation

# Initialize Terraform
terraform init

# Plan to see what would be created
terraform plan

# Apply the configuration (creates the resources)
terraform apply

# When finished testing, clean up
terraform destroy
```

### CI/CD Validation

This module is used by the `terraform-validation.yml` GitHub Actions workflow to verify that:

1. GitHub Actions can successfully authenticate to Azure using OIDC
2. The service principal has the necessary permissions
3. Terraform can plan and apply infrastructure changes
4. The entire CI/CD workflow functions correctly

For step-by-step guidance on running the full validation process, see the comprehensive [ValidationProcess.md](/OneTimeActivities/ValidationProcess.md) guide.

## Important Notes

- This validation module creates minimal resources that incur very low costs (storage account)
- All resources can be safely deleted after validation using `terraform destroy`
- Use this module before implementing more complex Terraform configurations

## What This Validation Verifies

This module specifically verifies that:

1. The Azure AD application registration and OIDC setup in [RegisterApplicationInAzureAndOIDC](/OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md) was completed correctly
2. The GitHub secrets for Azure authentication were properly configured
3. The service principal has sufficient permissions to create and manage resources
4. The GitHub Actions workflow can successfully authenticate to Azure using OIDC
5. Terraform can create, manage, and delete Azure resources through the CI/CD pipeline

## Best Practices

- Run this validation module when:
  - Setting up a new environment
  - Changing authentication methods
  - Modifying service principal permissions
  - Updating GitHub Actions workflows
  - Making significant changes to your Terraform structure

## Security Considerations

- This module follows the principle of least privilege
- The validation creates resources in a dedicated validation resource group
- All resources have appropriate tags for tracking and governance
- OIDC authentication eliminates the need for long-lived credentials
