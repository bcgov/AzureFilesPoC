# One-Time Activities for Azure Files PoC

This directory contains documentation and scripts for one-time onboarding activities required for the Azure Files Proof of Concept project.

## 📚 Key Documentation

- **[TROUBLESHOOTING_GUIDE.md](RegisterApplicationInAzureAndOIDC/TROUBLESHOOTING_GUIDE.md)** - Comprehensive troubleshooting for all onboarding issues
- **[SSH_KEY_REFERENCE.md](RegisterApplicationInAzureAndOIDC/SSH_KEY_REFERENCE.md)** - Complete SSH key management and Bastion connection guide
- **[Validation Process](ValidationProcess.md)** - End-to-end validation after onboarding

## 📁 Folder Structure

This directory is organized into logical sections for different types of one-time activities:

### RegisterApplicationInAzureAndOIDC/
Azure AD application registration, service principal creation, and OIDC configuration for GitHub Actions authentication.

### GitHubActionsSetup/
GitHub Actions workflow configuration, templates, and best practices for CI/CD automation.

### SelfHostedRunnerSetup/
Self-hosted GitHub Actions runner installation and configuration for data plane operations that require network access to Azure services.

### ValidationProcess.md
End-to-end validation procedures to confirm that all systems are working correctly after onboarding.

## Contents

- [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md) – Main onboarding and OIDC setup guide
- [GitHubActionsSetup/README.md](GitHubActionsSetup/README.md) – Configuration steps for GitHub Actions workflows and templates
- [SelfHostedRunnerSetup/README.md](SelfHostedRunnerSetup/README.md) – Self-hosted runner installation and configuration
- [ValidationProcess.md](ValidationProcess.md) – Steps to validate the end-to-end CI/CD pipeline after onboarding

## Quick Start: Onboarding Steps

The onboarding process is automated and modularized into 11 robust, idempotent scripts for Unix/macOS (Bash) only. Each script updates the shared `.env/azure-credentials.json` file incrementally and safely (except for resource group tags, which are set in Azure only). These steps are designed to comply with BC Gov Azure landing zone policy constraints and best practices for least-privilege, auditability, and automation.

**Run each script in order, verifying each step before proceeding:**

### Unix/macOS (Bash) Onboarding Scripts

| Step | Script | Purpose & Description |
|------|--------|----------------------|
| 1 | `step1_register_app.sh` | Register the Azure AD application and create a service principal for CI/CD. Required for OIDC and automation identity. |
| 2 | `step2_grant_permissions.sh` | Assign only the minimum required Azure roles to the service principal (e.g., Contributor at RG scope, custom roles for RBAC). Enforces least-privilege and BC Gov policy. |
| 3 | `step3_configure_oidc.sh` | Configure OIDC federated credentials for GitHub Actions. Enables secure, passwordless authentication (no long-lived secrets). |
| 4 | `step4_prepare_github_secrets.sh` | Extracts the required Azure identity values and prepares them for GitHub repository secrets. |
| 5 | `step5_add_github_secrets_cli.sh` | Adds the required secrets to your GitHub repository using the CLI for automation and consistency. |
| 6 | `step6_create_resource_group.sh` | Creates the permanent resource group for your project, with required tags and policy compliance. Must be run by a user with sufficient permissions. |
| 7 | `step7_create_tfstate_storage_account.sh` | Creates the storage account and blob container for Terraform state, enforcing BC Gov security and policy requirements (e.g., TLS, naming). |
| 8 | `step8_assign_storage_roles.sh` | Assigns the necessary data plane roles (e.g., Storage Blob Data Contributor) to the service principal for the state storage account. |
| 9 | `step9_validate_oidc_login.sh` | Validates that OIDC authentication from GitHub Actions to Azure works as expected. |
| 10 | `step10_validate_terraform_backend.sh` | Validates that the Terraform backend (remote state) is accessible and correctly configured. |
| 11 | `step11_create_ssh_key.sh` | Generates an SSH key pair for VM admin access. Public key is added to GitHub secrets for secure runner/VM provisioning. |
| 12 | `step12_import_existing_resources.sh` | Import pre-existing Azure resources (such as subnet/NSG associations) into Terraform state. Run after onboarding and before first terraform apply. |

**Example usage:**
```bash
./RegisterApplicationInAzureAndOIDC/scripts/unix/step1_register_app.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step2_grant_subscription_level_permissions.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step3_configure_github_oidc_federation.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step4_prepare_github_secrets.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step5_add_github_secrets_cli.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh <resource-group-name> [location]
./RegisterApplicationInAzureAndOIDC/scripts/unix/step7_create_tfstate_storage_account.sh --rgname <resource-group-name> --saname <storage-account-name> --containername <container-name> [--location <location>]
./RegisterApplicationInAzureAndOIDC/scripts/unix/step8_assign_storage_roles.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step9_validate_oidc_login.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step10_validate_terraform_backend.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step12_import_existing_resources.sh
```

- Each script is safe to re-run and will not duplicate entries.
- All scripts dynamically resolve the project root and credentials file location.
- The onboarding process is fully documented in [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md).
- **All onboarding and automation scripts are maintained and supported for Unix/macOS (Bash) only.**
- **Resource group tags are set in Azure only and are not written to the credentials JSON.**

## Additional Required One-Time Steps (June 2025)

### 1. Generate and Register SSH Key for VM Admin Access
- Run the provided script to generate an SSH key pair for VM admin access:
  ```sh
  ./RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
  ```
- Copy the entire contents of the generated public key (`id_rsa.pub`, including the `ssh-rsa` prefix) into your GitHub repository secret (e.g., `ADMIN_SSH_KEY_PUBLIC`).
- This is only required in GitHub secrets for CI/CD workflows. You do not need to add it to `secrets.tfvars` unless you want to use it for local automation.

### 2. Update Project Tree Structure
- Use the following command to generate a clean directory tree (excluding build, library, and sensitive files):
  ```sh
  tree -I 'node_modules|.terraform|.vscode|.idea|.git|*.zip|*.tar|*.gz|*.swp|*.swo|*.DS_Store|Thumbs.db|*.tfstate*|*.auto.tfvars*|*.bak|*.lock.hcl|llm_code_snapshot.txt|package-lock.json|.azure|.env|*.plan|LICENSE.txt|*.log' -a -F > TreeStructure.txt
  ```
- This will help you keep your `TreeStructure.txt` up to date and clean.

## Inventory and Terraform Automation

After onboarding, you can use the provided inventory and tfvars population scripts to automate resource discovery and Terraform variable management:

- **Unix/macOS (Bash):**
  - `OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh`
  - `OneTimeActivities/GetAzureExistingResources/unix/PopulateTfvarsFromDiscoveredResources.sh`

These scripts generate and update `.env/azure_full_inventory.json`, `terraform.tfvars`, and `secrets.tfvars` in a robust, idempotent manner. See the respective script folders for usage instructions.

## Transition to Validation

After completing all onboarding scripts and confirming your GitHub secrets are set, proceed to the validation phase:

1. Follow the complete [Validation Process](ValidationProcess.md) for step-by-step instructions and troubleshooting.
2. Use the [Azure Login Validation workflow](../../.github/workflows/azure-login-validation.yml) to verify OIDC authentication.
3. Use the [Terraform Validation workflow](../../.github/workflows/terraform-validation.yml) to validate the end-to-end CI/CD pipeline.

## Security Considerations

- All onboarding scripts follow the principle of least privilege and update only the required sections of the credentials file.
- No secrets are ever written to version control; `.env/azure-credentials.json` is git-ignored.
- All steps are idempotent and safe to repeat.
- Resource group tags are managed in Azure only. If you change tags later, update them directly in Azure using the CLI or Portal.

## Why the Step-by-Step Approach?

The step-by-step approach with verification between steps ensures:

1. **Security**: Each security change is verified before proceeding
2. **Auditability**: A clear record exists of what was done and when
3. **Error Prevention**: Problems are caught early rather than at the end of a long process
4. **Documentation**: The process is fully documented as you go
5. **Knowledge Transfer**: The process can be understood and replicated by others

## Progress Tracking

Update the Progress Tracking table in [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md) as you complete each step.

## Next Steps

After onboarding, always validate your setup before proceeding with any infrastructure automation. The validation process is the authoritative pattern for all future onboarding and resource creation in this PoC.

## One-Time Import of Existing Resources into Terraform State

In addition to the onboarding steps, you may need to import existing Azure resources into Terraform state. This is necessary if you have resources that were created outside of Terraform but now need to be managed by Terraform (e.g., subnet/NSG associations).

### 1. Import Pre-Existing Azure Resources into Terraform State
- Run the provided script to import any Azure resources that were created outside of Terraform but must now be managed by Terraform (e.g., subnet/NSG associations):
  ```sh
  ./RegisterApplicationInAzureAndOIDC/scripts/unix/step12_import_existing_resources.sh
  ```
- Edit the script to specify the correct Terraform resource address and Azure resource ID for your environment.
- This is a one-time operation per environment. After import, Terraform will manage the resource as normal.

Ensure that you have completed all onboarding steps and your GitHub secrets are set before running the import script. After importing, proceed to the validation phase to verify your setup.
