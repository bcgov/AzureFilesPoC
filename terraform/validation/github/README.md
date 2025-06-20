# GitHub Actions Validation for Azure OIDC Authentication

## Purpose

This directory contains guidance for validating the Azure application registration and OIDC setup using GitHub Actions.

## Prerequisites

Before running GitHub Actions validation:

1. Complete the [Application Registration for Azure](../../../OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md) process up to Step 4
2. Ensure the GitHub secrets have been properly configured:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`

## Validation Steps

### Step 1: Verify GitHub Secrets

1. Go to your GitHub repository's Settings > Secrets and variables > Actions
2. Verify all three secrets are present and have the correct values
3. These secrets should match the values in your `.env/azure-credentials.json` file

### Step 2: Run the GitHub Actions Workflow

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

### What This Validates

GitHub Actions validation confirms:
1. OIDC authentication is working correctly
2. GitHub secrets are configured properly
3. The service principal has the correct permissions
4. The CI/CD pipeline is functioning end-to-end

## GitHub Actions Workflow Details

The `terraform-validation.yml` workflow includes the following key steps:

1. Check out the repository
2. Set up Terraform
3. Authenticate to Azure using OIDC
4. Initialize Terraform
5. Plan the infrastructure changes
6. Apply the configuration (creating resources)
7. Verify resource creation
8. Optionally clean up resources

## Relationship to Other Validation

This is "Step 3B: GitHub Actions Validation" from the main [ValidationProcess.md](../../../OneTimeActivities/ValidationProcess.md) document. This validation should be performed after Step 3A: Local Validation has succeeded.
