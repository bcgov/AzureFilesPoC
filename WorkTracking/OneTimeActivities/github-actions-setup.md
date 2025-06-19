# GitHub Actions Setup for Azure Files PoC

This document explains how to set up and use GitHub Actions for the Azure Files Proof of Concept project.

## Overview

GitHub Actions enables automating the deployment of Azure infrastructure from Terraform code in this project. We've created a workflow that:
1. Logs into Azure using federated credentials (OIDC)
2. Runs a simple `az account show` command to verify login success
3. No resources are created or modified in this initial test

## See also BC Govt Best practices CI/CD and Githbub
[https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#github-actions)

## summary of github related action OIDC authentication in azure from above resource
- Use OpenID Connect (OIDC) authentication in GitHub Actions to securely access Azure subscriptions.
- Register an Entra ID Application and Service Principal in Azure, add federated credentials, and store Azure configuration as GitHub secrets.
- In workflows, set permissions and use the `azure/login` action to exchange the OIDC token for Azure access.
- For accessing Azure data storage and databases, use self-hosted runners on Azure; public access is not supported.
- Microsoft provides sample Terraform code for deploying self-hosted runners in the `azure-lz-samples` repository.
- Review prerequisites for self-hosted runners, especially subnet requirements, as described in the relevant README.


## Prerequisites

Before using GitHub Actions:

1. Your code must be in a GitHub repository
2. You need admin access to the repository to configure secrets
3. You need permissions in Azure to create an application registration
4. Application registration must be completed as described in [RegisterApplicationInAzure.md](./RegisterApplicationInAzure.md)

## Validation Workflow

After setting up the service principal and GitHub secrets, you should validate that GitHub Actions can successfully authenticate to Azure before attempting to deploy any infrastructure.

### How to Run the Validation Test

1. Go to your GitHub repository and navigate to the "Actions" tab
2. Select the "Azure Login Validation" workflow from the list
3. Click the "Run workflow" button
4. Choose whether to use OIDC authentication (recommended) or credential-based authentication
5. Click the "Run workflow" button to start the validation

### What the Validation Tests

The validation workflow performs these tests:
1. Authenticates to Azure using your configured credentials
2. Runs `az account show` to verify the connection
3. Lists resource groups to confirm proper permissions
4. Reports success or failure without modifying any resources

### If Validation Fails

If the validation fails:
1. Check that all GitHub secrets are correctly configured
2. Verify that the service principal has appropriate roles assigned
3. For OIDC, confirm that the federated credential is properly configured
4. Review the error messages in the workflow run logs for specific issues

## Implementation Process

For this project, we follow this implementation process:

1. **Manual Testing First**: Test all commands manually via command line before automating
2. **One-Time Setup Activities**: Complete prerequisites (app registration, permissions, etc.)
3. **Simple Test Workflow**: Verify Azure authentication works before implementing Terraform
4. **Full Automation**: Implement complete Terraform workflow with proper approvals

## One-Time Setup Activities

The following setup tasks must be completed once before GitHub Actions can work:

1. **Register an Application in Azure**: 
   - See [RegisterApplicationInAzure.md](WorkTracking/OneTimeActivities/RegisterApplicationInAzure.md) for step-by-step instructions
   - **IMPORTANT**: Follow the step-by-step process, verifying each step in the Azure portal before continuing
   - This creates a service principal for GitHub Actions to authenticate with Azure

## Setup Instructions

> ⚠️ **Do not perform these steps directly from this document**. Instead, follow the detailed step-by-step instructions in [RegisterApplicationInAzure.md](WorkTracking/OneTimeActivities/RegisterApplicationInAzure.md) to ensure proper verification and documentation of each step.

# Get your subscription ID
$subscriptionId=$(az account show --query id -o tsv)
echo "Subscription ID: $subscriptionId"

# Assign the Reader role to the service principal at the subscription level
# This is a minimal permission just for testing login
az role assignment create --assignee $appId --role Reader --scope /subscriptions/$subscriptionId
```

### Complete Setup Process

After completing step 1 in the [RegisterApplicationInAzure.md](WorkTracking/OneTimeActivities/RegisterApplicationInAzure.md) document, you'll continue with:

1. Granting permissions to the service principal
2. Configuring federated credentials for OIDC authentication
3. Storing necessary GitHub secrets
4. Verifying the setup with a test workflow

Each step must be completed in sequence with proper verification as outlined in the detailed instructions.

## Running the Workflow

### Option 1: Manual Trigger (Recommended for first test)

1. Go to your GitHub repository
2. Click on the "Actions" tab
3. Select the "Azure Login Test" workflow
4. Click "Run workflow"
5. Click the green "Run workflow" button

### Option 2: Pull Request Trigger

1. Uncomment the pull_request trigger in the YAML file
2. Create a new branch
3. Make a change and push to that branch
4. Create a pull request to main
5. The workflow will run automatically

### Option 3: Push Trigger

1. Uncomment the push trigger in the YAML file
2. Push changes to the main branch
3. The workflow will run automatically

## Viewing Results

1. Go to the "Actions" tab in your GitHub repository
2. Click on the workflow run
3. Review the logs to see if the login was successful

## Next Steps After Successful Login Test

Once this simple login test passes, you can expand the workflow to:
1. Set up Terraform
2. Run `terraform init`
3. Run `terraform plan`
4. (With approval) Run `terraform apply`

## Documentation and Tracking

For this project, we maintain documentation of all steps taken:

1. Keep the [RegisterApplicationInAzure.md](WorkTracking/OneTimeActivities/RegisterApplicationInAzure.md) document updated with the status of each step
2. Update the Progress Tracking table as you complete each step
3. Document any issues encountered and their resolutions

> **Security Best Practice**: All configuration steps should be manually verified before proceeding to the next step. This ensures proper setup and helps identify any potential security or permission issues early.
