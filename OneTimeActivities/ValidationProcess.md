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
3. **Run the Azure resource inventory automation:**
   - Use the provided inventory script for your platform to generate `.env/azure_full_inventory.json`:
     - Unix/macOS: `OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh`
     - Windows: `OneTimeActivities/GetAzureExistingResources/windows/azure_full_inventory.ps1`
   - This file is required for onboarding, tfvars population, and validation automation.
4. **Populate Terraform variable files using automation:**
   - Use the population script to generate/update `terraform.tfvars` and `secrets.tfvars` from `.env/azure_full_inventory.json`:
     - Unix/macOS: `OneTimeActivities/GetAzureExistingResources/unix/PopulateTfvarsFromDiscoveredResources.sh`
     - Windows: `OneTimeActivities/GetAzureExistingResources/windows/PopulateTfvarsFromDiscoveredResources.ps1`
   - This ensures all required variables (including new naming conventions) are set for validation.
5. Basic familiarity with GitHub Actions and Terraform

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
https://github.com/bcgov/AzureFilesPoC/actions/workflows/azure-login-validation.yml
3. Click **Run workflow** and use the default settings (OIDC authentication)
**note:** wait a few seconds you'll see something like
Azure Login Validation #1: Manually run by richfrem (In progress)
4. Wait for the workflow to complete and verify:
   - All steps show green checkmarks
   - The workflow output shows "Successfully authenticated with Azure!"
   - The resource group listing runs without errors

   > **Note:** This authentication validation was performed using the [`azure-login-validation.yml`](../../.github/workflows/azure-login-validation.yml) workflow in GitHub by manually triggering the workflow from the Actions tab.

## Step 2: Validate Terraform Configuration

This step validates that Terraform can successfully create resources:

After confirming that Azure authentication works via GitHub Actions, the next phase is to ensure your infrastructure-as-code automation is fully functional. This is done in two parts:

- **Step 2A: Localhost Validation** – Run scripts on your local machine to confirm that your credentials, Azure CLI, and Terraform setup can create and destroy resources in Azure. This helps catch local configuration or permission issues before relying on CI/CD.

> **Note:** All onboarding, inventory, and tfvars automation scripts are available and supported for both Unix/macOS (Bash) and Windows (PowerShell). Use the appropriate script for your platform when performing local validation. See the `OneTimeActivities/GetAzureExistingResources/unix` and `windows` folders for details.

For detailed instructions and troubleshooting for Step 2A, see the [Local Validation README](/terraform/validation/localhost/README.md). This document covers prerequisites, environment setup, script usage, expected outputs, and common issues encountered during local validation. It provides step-by-step guidance for running the authentication and Terraform validation scripts, interpreting results, and resolving errors.

**NOTE:**. this approach instead of running terraform scripts through github, it will be using azure CLI and azure login then running scripts locally to debug them before going to github. 

For Step 2B, refer to the [GitHub Actions Validation README](/terraform/validation/github/README.md) for workflow-specific instructions. This includes details on configuring workflow inputs, understanding workflow logs, handling secrets, and troubleshooting CI/CD-specific issues. The README ensures you have all necessary context to validate Terraform automation in the GitHub Actions environment.

Consulting these READMEs ensures you have access to comprehensive instructions and troubleshooting resources for both local and CI/CD validation steps.

- **Step 2B: GitHub Actions Validation** – Run the Terraform validation workflow in GitHub Actions to confirm that your CI/CD pipeline can also create and destroy resources using the same OIDC authentication and secrets. This ensures your automation works in the same environment as production deployments.

Both validations are important: local validation gives you fast feedback and troubleshooting, while CI/CD validation ensures your end-to-end pipeline is ready for real-world use. Complete both before moving on to actual infrastructure work.


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
# Run the authentication validation script (Bash or PowerShell, depending on your OS)
./terraform/validation/localhost/validate_authentication.sh   # Unix/macOS
./terraform/validation/localhost/validate_authentication.ps1  # Windows

# Run the Terraform validation script
./terraform/validation/localhost/validate_terraform.sh        # Unix/macOS
./terraform/validation/localhost/validate_terraform.ps1       # Windows
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
