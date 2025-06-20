# Azure Files PoC Validation Guide

## Purpose

This document provides step-by-step guidance for validating the end-to-end CI/CD pipeline for the Azure Files Proof of Concept (PoC) project. It serves as a structured approach to verify that all components of the automation framework are working together before implementing production infrastructure.

## Prerequisites

Before following this validation guide, ensure you have completed:

1. [Application Registration for Azure](RegisterApplicationInAzureAndOIDC/README.md) - The registration process must be completed up to Step 4
2. [GitHub Secrets Configuration](RegisterApplicationInAzureAndOIDC/README.md#4-prepare-and-store-github-secrets) - All required secrets must be stored in GitHub: (step 5 was completed)
   - `AZURE_CLIENT_ID` - From the application registration
   - `AZURE_TENANT_ID` - Your Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID
   
   You can verify these secrets are configured by checking your credentials file at `.env/azure-credentials.json` under the `github.secrets` section.
3. Basic familiarity with GitHub Actions and Terraform

## Overview of Validation Process

This validation process follows BC Government best practices by ensuring all components work together before implementing production infrastructure:

1. **Authentication Validation** - Verify Azure authentication works
2. **Permission Validation** - Check that the service principal has required permissions
3. **Terraform Validation** - Confirm Terraform can create simple resources
4. **CI/CD Workflow Validation** - Ensure the complete pipeline functions correctly



## Step 1: Validate Azure Authentication

The first step is to validate basic authentication to Azure:
1. open  https://github.com/bcgov/AzureFilesPoC/settings
2. Navigate to the **Actions** tab in your GitHub repository https://github.com/bcgov/AzureFilesPoC/actions
2. Select the **Azure Login Validation** workflow
3. Click **Run workflow** and use the default settings (OIDC authentication)
4. Wait for the workflow to complete and verify:
   - All steps show green checkmarks
   - The workflow output shows "Successfully authenticated with Azure!"
   - The resource group listing runs without errors

## Step 2: Validate Terraform Configuration

This step validates that Terraform can successfully create resources:

### Step 2A: Local Validation

#### Purpose

The local validation step ensures your development environment is correctly configured to authenticate with Azure and use Terraform. It validates that:

- Your `.env/azure-credentials.json` file contains the required secrets
- Azure CLI authentication works with your credentials
- Terraform can initialize, plan, apply, and destroy resources locally
- Resource creation and cleanup function as expected

This step helps catch configuration or permission issues before running workflows in CI/CD.


First, test locally on your development machine using the [Terraform Validation Module](/terraform/validation):

```shell
# Run the authentication validation script
./terraform/validation/localhost/validate_authentication.sh

# Run the Terraform validation script
./terraform/validation/localhost/validate_terraform.sh
```

The scripts above handle:
1. Extracting credentials from your `.env/azure-credentials.json` file
2. Authenticating with Azure CLI
3. Running Terraform init, plan, apply
4. Verifying resource creation
5. Cleaning up resources

For detailed instructions and troubleshooting, see the [Local Validation README](/terraform/validation/localhost/README.md).

### Step 2B: GitHub Actions Validation

#### Purpose
The GitHub Actions validation step ensures your CI/CD pipeline can authenticate with Azure and execute Terraform workflows using the configured secrets. It validates that:

- OIDC authentication works in the GitHub Actions environment
- The workflow can access and use the required secrets
- Terraform can initialize, plan, apply, and destroy resources via GitHub Actions
- Resource creation and cleanup are successful in a non-local context

This step confirms that your automation works as expected in the same environment used for production deployments.

After successful local validation, proceed to validate the complete CI/CD pipeline using the same [Terraform Validation Module](/terraform/validation):

1. Navigate to the **Actions** tab in your GitHub repository
2. Select the **Terraform Validation Workflow**
3. Click **Run workflow** and use these settings:
   - **Environment**: dev (or your target environment)
   - **Cleanup**: true (to automatically clean up resources)
4. Wait for the workflow to complete and verify:
   - All steps show green checkmarks
   - The "Verify Resource Creation" step shows "Succeeded"
   - You can see the blob URL in the workflow outputs
   - If cleanup is enabled, the resources are removed after validation

This validation uses OIDC authentication with your GitHub secrets to authenticate with Azure.

For detailed instructions and troubleshooting, see the [GitHub Actions Validation README](/terraform/validation/github/README.md).

## What This Validation Tests

This validation process tests multiple components of your Azure automation:

| Component | What's Validated |
|-----------|------------------|
| **Azure Authentication** | OIDC token exchange and successful login |
| **Azure Permissions** | Service principal can create, list, and delete resources |
| **Terraform Configuration** | Initialization, plan, apply, and destroy functionality |
| **GitHub Actions** | Workflow execution, secret handling, and environment management |
| **Infrastructure Creation** | End-to-end resource provisioning without errors |

## Validation Success Criteria

Your validation is considered successful when all these criteria are met:

- ✅ Required GitHub secrets are properly configured and tracked
- ✅ Authentication to Azure succeeds using OIDC
- ✅ GitHub Actions workflows complete without errors
- ✅ Terraform can create and destroy resources
- ✅ Service principal has appropriate permissions
- ✅ All validation resources are properly cleaned up
- ✅ Credentials file accurately reflects the current state

## Applying This Process to Future Development

This validation pattern should be applied to all future resource creation:

1. **Develop Locally First** - Write and test Terraform code locally
2. **Small, Incremental Changes** - Add one resource type at a time
3. **Validate Each Addition** - Test each addition through the GitHub workflow
4. **Document Validation Results** - Keep track of validation status for each component

## Revalidation Requirements

Revalidate the pipeline when any of these changes occur:

- Service principal permissions are modified
- GitHub Actions workflow files are updated
- Authentication method changes (e.g., from OIDC to service principal)
- Major updates to Terraform versions or providers
- Changes to Azure subscription or Azure AD tenant

## Troubleshooting Common Issues

If validation fails, check these common issues:

| Issue | Troubleshooting Steps |
|-------|------------------------|
| Authentication Failure | Verify GitHub secrets contain correct values |
| Permission Errors | Check service principal role assignments |
| Terraform Provider Errors | Verify provider version compatibility |
| Resource Creation Failures | Check for Azure resource quota issues or policy blocks |
| Workflow Failures | Check GitHub Action logs for detailed error messages |

Remember: When troubleshooting, start with the simplest possible test (Azure login) before moving to more complex tests (Terraform apply).

## Additional Resources

- [BC Government IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- [GitHub Actions for Terraform](https://learn.hashicorp.com/tutorials/terraform/github-actions)
- [Azure Authentication for GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
