# Archived: Terraform & CI/CD Pipeline Code

> **Status:** ARCHIVED - Not currently in use. Project pivoted to Bicep scripts for primary deployment.

This folder contains the original Terraform and GitHub Actions CI/CD pipeline infrastructure that was developed before pivoting to Bicep scripts.

## Why Archived?

The project initially used Terraform with GitHub Actions for automated CI/CD deployment. While functional, the team pivoted to **Bicep scripts** for the following reasons:

1. **Simpler deployment**: Direct Azure CLI + Bicep is faster for PoC validation
2. **BC Gov policy compliance**: Bicep templates were easier to adapt to landing zone constraints
3. **Reduced complexity**: No need for self-hosted runner, state management, or OIDC setup

## Contents

```
scripts/ARCHIVE/
├── README.md                    # This file
├── terraform/                   # Terraform modules and configurations
│   ├── modules/                 # Reusable Terraform modules
│   ├── environments/            # Environment-specific configs (dev/prod)
│   └── README.md               # Terraform-specific documentation
├── OneTimeActivities/           # OIDC, GitHub Actions, and runner setup
│   ├── RegisterApplicationInAzureAndOIDC/   # Azure AD app & OIDC federation
│   ├── GitHubActionsSetup/                  # Workflow templates
│   ├── SelfHostedRunnerSetup/               # Runner VM scripts
│   └── GetAzureExistingResources/           # Resource discovery scripts
└── github-workflows/            # GitHub Actions workflows (if moved)
```

## Can This Be Used?

**Yes!** This code is fully functional and can be used if you want to:

1. **Automate deployments** via GitHub Actions CI/CD pipeline
2. **Use Terraform** instead of Bicep for infrastructure as code
3. **Set up a self-hosted runner** for private network access

### Prerequisites for Terraform CI/CD

1. Azure AD application with OIDC federation (see `OneTimeActivities/RegisterApplicationInAzureAndOIDC/`)
2. GitHub repository secrets configured (see `OneTimeActivities/GitHubActionsSetup/`)
3. Self-hosted runner VM (see `OneTimeActivities/SelfHostedRunnerSetup/`)
4. Terraform state storage account

### Key Learnings

The Bicep deployment taught us patterns that apply equally to Terraform:

- **Private endpoints require existing DNS zones** (BC Gov manages these centrally)
- **Cross-region deployments work** (PE in canadacentral → resources in canadaeast)
- **Phased deployment order matters** (networking → storage → compute → AI → connectivity)
- **Azure Policy blocks public IPs** on PaaS services

## Related Documentation

- [Deployment Guide](../../docs/guides/deployment-guide.md) - Current Bicep deployment process
- [CI/CD Runner Setup](./OneTimeActivities/SelfHostedRunnerSetup/README.md) - Self-hosted runner docs
- [OIDC Setup](./OneTimeActivities/RegisterApplicationInAzureAndOIDC/README.md) - Azure AD federation

## Reactivating Terraform CI/CD

If you want to convert back to Terraform CI/CD:

1. Review and update Terraform modules in `terraform/`
2. Run the OneTimeActivities scripts to set up OIDC
3. Move workflows from `github-workflows/` back to `.github/workflows/`
4. Update `terraform/environments/` with current resource names

The Bicep templates in `bicep/` can serve as a reference for the current architecture.
