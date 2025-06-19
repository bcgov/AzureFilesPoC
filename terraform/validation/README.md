# Terraform Validation Module

## Purpose

This module provides a minimal Terraform configuration to validate the Azure authentication, permissions, and CI/CD workflow without creating significant resources or incurring costs. It's designed as a "smoke test" for your Terraform infrastructure-as-code setup.

## What This Module Creates

- A simple resource group with appropriate tags
- No other Azure resources

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

# Apply the configuration (creates the resource group)
terraform apply

# When finished testing, clean up
terraform destroy
```

### CI/CD Validation

This module is used by the `terraform-validation.yml` GitHub Actions workflow to verify that:

1. GitHub Actions can successfully authenticate to Azure
2. The service principal has the necessary permissions
3. Terraform can plan and apply infrastructure changes
4. The entire CI/CD workflow functions correctly

## Important Notes

- This validation module creates minimal resources that incur no additional costs
- The resource group can be safely deleted after validation
- Use this module before implementing more complex Terraform configurations

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
