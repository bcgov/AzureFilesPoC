# GitHub Actions Workflows

The CI/CD workflows for Terraform deployment have been archived to `scripts/ARCHIVE/github-workflows/`.

This project currently uses **Bicep scripts** deployed via Azure CLI for infrastructure management.

## Archived Workflows

The following workflows are available in `scripts/ARCHIVE/github-workflows/` if CI/CD automation is needed:

- `main.yml` - Main Terraform deployment workflow
- `runner-infra.yml` - Self-hosted runner infrastructure
- `azure-login-validation.yml` - OIDC authentication test
- `test-self-hosted-runner.yml` - Runner validation

## Reactivating CI/CD

To use GitHub Actions with Terraform:

1. Move workflows from `scripts/ARCHIVE/github-workflows/` back to `.github/workflows/`
2. Follow the setup in `scripts/ARCHIVE/OneTimeActivities/`
3. Configure repository secrets for OIDC authentication

See `scripts/ARCHIVE/README.md` for details.
