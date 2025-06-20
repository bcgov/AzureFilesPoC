# One-Time Activities for Azure Files PoC

This directory contains documentation and scripts for one-time onboarding activities required for the Azure Files Proof of Concept project.

## Contents

- [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md) – Main onboarding and OIDC setup guide
- [github-actions-setup.md](github-actions-setup.md) – Configuration steps for GitHub Actions workflows
- [ValidationProcess.md](ValidationProcess.md) – Steps to validate the end-to-end CI/CD pipeline after onboarding

## Quick Start: Onboarding Steps

The onboarding process is automated and modularized into 5 robust, idempotent scripts for both Unix and Windows. Each script updates the shared `.env/azure-credentials.json` file incrementally and safely.

**Run each script in order, verifying each step before proceeding:**

### Unix/macOS
```bash
./RegisterApplicationInAzureAndOIDC/scripts/unix/step1_register_app.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step2_grant_permissions.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step3_configure_oidc.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step4_prepare_github_secrets.sh
./RegisterApplicationInAzureAndOIDC/scripts/unix/step5_add_github_secrets_cli.sh
```

### Windows (PowerShell)
```powershell
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step1_register_app.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step2_grant_permissions.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step3_configure_oidc.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step4_prepare_github_secrets.ps1
.\RegisterApplicationInAzureAndOIDC\scripts\windows\step5_add_github_secrets_cli.ps1
```

- Each script is safe to re-run and will not duplicate entries.
- All scripts dynamically resolve the project root and credentials file location.
- The onboarding process is fully documented in [RegisterApplicationInAzureAndOIDC/README.md](RegisterApplicationInAzureAndOIDC/README.md).

## Transition to Validation

After completing all 5 onboarding scripts and confirming your GitHub secrets are set, proceed to the validation phase:

1. Follow the complete [Validation Process](ValidationProcess.md) for step-by-step instructions and troubleshooting.
2. Use the [Azure Login Validation workflow](../../.github/workflows/azure-login-validation.yml) to verify OIDC authentication.
3. Use the [Terraform Validation workflow](../../.github/workflows/terraform-validation.yml) to validate the end-to-end CI/CD pipeline.


## Security Considerations

- All onboarding scripts follow the principle of least privilege and update only the required sections of the credentials file.
- No secrets are ever written to version control; `.env/azure-credentials.json` is git-ignored.
- All steps are idempotent and safe to repeat.

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
