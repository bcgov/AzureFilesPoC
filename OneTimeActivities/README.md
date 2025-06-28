# One-Time Activities for Azure Files PoC

This directory contains documentation and scripts for one-time onboarding activities required for the Azure Files Proof of Concept project.

## Contents

- [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md) – Main onboarding and OIDC setup guide
- [github-actions-setup.md](github-actions-setup.md) – Configuration steps for GitHub Actions workflows
- [ValidationProcess.md](ValidationProcess.md) – Steps to validate the end-to-end CI/CD pipeline after onboarding

## Quick Start: Onboarding Steps

The onboarding process is automated and modularized into 6 robust, idempotent scripts for both Unix/macOS (Bash) and Windows (PowerShell). Each script updates the shared `.env/azure-credentials.json` file incrementally and safely (except for resource group tags, which are set in Azure only).

**Run each script in order, verifying each step before proceeding:**

### Unix/macOS (Bash)
```bash
./RegisterApplicationInAzureAndOIDC/scripts/unix/step1_register_app.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step2_grant_permissions.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step3_configure_oidc.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step4_prepare_github_secrets.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step5_add_github_secrets_cli.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh <resource-group-name> [location]
```

**Before running the onboarding scripts on Windows, install the Azure PowerShell module:**

```powershell
Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
```

- Run PowerShell as Administrator for best results.
- If prompted to trust the repository, answer 'Yes'.
- After installation, you may need to restart your PowerShell session.

### Windows (PowerShell)
```powershell
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step1_register_app.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step2_grant_permissions.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step3_configure_oidc.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step4_prepare_github_secrets.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step5_add_github_secrets_cli.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step6_create_resource_group.ps1 -rgname <resource-group-name> [-location <location>]
```

- Each script is safe to re-run and will not duplicate entries.
- All scripts dynamically resolve the project root and credentials file location.
- The onboarding process is fully documented in [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md).
- **All onboarding and automation scripts are maintained and supported for both platforms.**
- **Resource group tags are set in Azure only and are not written to the credentials JSON.**

## Inventory and Terraform Automation (Cross-Platform)

After onboarding, you can use the provided inventory and tfvars population scripts to automate resource discovery and Terraform variable management:

- **Unix/macOS (Bash):**
  - `OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh`
  - `OneTimeActivities/GetAzureExistingResources/unix/PopulateTfvarsFromDiscoveredResources.sh`
- **Windows (PowerShell):**
  - `OneTimeActivities/GetAzureExistingResources/windows/azure_full_inventory.ps1`
  - `OneTimeActivities/GetAzureExistingResources/windows/PopulateTfvarsFromDiscoveredResources.ps1`

These scripts generate and update `.env/azure_full_inventory.json`, `terraform.tfvars`, and `secrets.tfvars` in a robust, cross-platform manner. See the respective script folders for usage instructions.

## Transition to Validation

After completing all 6 onboarding scripts and confirming your GitHub secrets are set, proceed to the validation phase:

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
