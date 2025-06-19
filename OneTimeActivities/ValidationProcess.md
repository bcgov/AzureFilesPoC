# Azure Files PoC Validation Guide

## Purpose

This document provides step-by-step guidance for validating the end-to-end CI/CD pipeline for the Azure Files Proof of Concept (PoC) project. It serves as a structured approach to verify that all components of the automation framework are working together before implementing production infrastructure.

## Prerequisites

Before following this validation guide, ensure you have completed:

1. [Application Registration for Azure](RegisterApplicationInAzure.md) - The registration process must be completed up to Step 4
2. [GitHub Secrets Configuration](RegisterApplicationInAzure.md#step-4-store-credentials-as-github-secrets) - All required secrets must be stored in GitHub
3. Basic familiarity with GitHub Actions and Terraform

## Overview of Validation Process

This validation process follows BC Government best practices by ensuring all components work together before implementing production infrastructure:

1. **Authentication Validation** - Verify Azure authentication works
2. **Permission Validation** - Check that the service principal has required permissions
3. **Terraform Validation** - Confirm Terraform can create simple resources
4. **CI/CD Workflow Validation** - Ensure the complete pipeline functions correctly

## Step 1: Validate Azure Authentication

The first step is to validate basic authentication to Azure:

1. Navigate to the **Actions** tab in your GitHub repository
2. Select the **Azure Login Validation** workflow
3. Click **Run workflow** and use the default settings (OIDC authentication)
4. Wait for the workflow to complete and verify:
   - All steps show green checkmarks
   - The workflow output shows "Successfully authenticated with Azure!"
   - The resource group listing runs without errors

## Step 2: Validate Terraform Configuration

This step validates that Terraform can successfully create resources:

### Option A: Local Validation

For testing locally on your development machine:

```shell
# Navigate to the validation directory
cd terraform/validation

# Initialize Terraform
terraform init

# Run a plan to see what would be created
terraform plan

# Apply the configuration (creates the resource group)
terraform apply

# When finished testing, clean up
terraform destroy
```

### Option B: GitHub Actions Validation

For validating the complete CI/CD pipeline:

1. Navigate to the **Actions** tab in your GitHub repository
2. Select the **Terraform Validation Workflow**
3. Click **Run workflow** and use these settings:
   - **Environment**: dev (or your target environment)
   - **Cleanup**: true (to automatically clean up resources)
4. Wait for the workflow to complete and verify:
   - All steps show green checkmarks
   - The "Verify Resource Creation" step shows "Succeeded"
   - If cleanup is enabled, the resources are removed after validation

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

- ✅ Authentication to Azure succeeds using OIDC
- ✅ GitHub Actions workflows complete without errors
- ✅ Terraform can create and destroy resources
- ✅ Service principal has appropriate permissions
- ✅ All validation resources are properly cleaned up

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
