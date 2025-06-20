# Local Validation for Azure OIDC Setup

This folder contains scripts and instructions for validating your Azure AD application registration and OIDC setup locally before using GitHub Actions.

## Purpose

Local validation allows you to verify that:
1. Your Azure credentials are correctly configured
2. Your service principal has the necessary permissions
3. You can authenticate and create resources in Azure

This validation serves as a pre-check before running the GitHub Actions workflows to ensure everything is set up correctly.

## Prerequisites

Before running local validation:
1. Complete all steps in the [RegisterApplicationInAzureAndOIDC](../../OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md) process
2. Have the `.env/azure-credentials.json` file properly populated
3. Have Azure CLI installed locally

## Validation Scripts

### 1. Basic Authentication Validation

This script validates that you can authenticate to Azure using the credentials from your `.env/azure-credentials.json` file:

```bash
./validate_authentication.sh
```

### 2. Terraform Validation

This script runs Terraform locally using the same credentials that would be used by GitHub Actions:

```bash
./validate_terraform.sh
```

## How Local Validation Works

Unlike GitHub Actions which uses OIDC federation for passwordless authentication, local validation:
1. Reads credentials from your `.env/azure-credentials.json` file
2. Uses Azure CLI to authenticate with these credentials
3. Runs the same Terraform code used by the GitHub Actions workflow

This provides a consistent testing experience while working within the constraints of local development.

## Running Local Validation

Follow these steps to validate your setup locally:

1. Make sure you're in the project root directory
2. Run the authentication validation script:
   ```
   ./terraform/validation/localhost/validate_authentication.sh
   ```
3. If successful, run the Terraform validation script:
   ```
   ./terraform/validation/localhost/validate_terraform.sh
   ```
4. Check the output to verify all components are working correctly

## Troubleshooting

If validation fails:
- Ensure all steps in the RegisterApplicationInAzureAndOIDC process were completed
- Verify the permissions assigned to your service principal
- Check that your `.env/azure-credentials.json` file contains the correct values
- Make sure you're authenticated to the right Azure subscription
