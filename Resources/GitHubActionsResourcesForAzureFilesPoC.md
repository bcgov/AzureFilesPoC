# GitHub Actions Resources for Azure Files PoC

## Overview

This document focuses on GitHub Actions and runners configuration specific to BC Government context for Azure Files PoC implementation. For Terraform-specific details, please refer to [TerraformResourcesForAzurePoC.md](./TerraformResourcesForAzurePoC.md).

## GitHub Actions Authentication

### OpenID Connect (OIDC) Authentication
BC Government requires using OIDC authentication for GitHub Actions to access Azure subscriptions securely. The GitHub Identity Provider is pre-configured in Azure Project Set subscriptions.

Setup process:
1. Azure Configuration:
   - Create Entra ID Application and Service Principal
   - Configure federated credentials for the Entra ID Application
   - Set up GitHub secrets for Azure configuration

2. GitHub Workflow Configuration:
   - Configure permissions for token access
   - Implement azure/login action for OIDC token exchange

For detailed implementation steps, refer to the [GitHub Actions OIDC Authentication Guide](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/).

## Self-Hosted Runners

### BC Government Requirements
- Self-hosted runners on Azure are mandatory for accessing data storage and database services
- Public access to these services is not supported

### Implementation Resources
- Microsoft's Azure Verified Module (AVM) for CICD Agents and Runners is approved for BC Government use
- Sample implementation code available in [Azure Landing Zone Samples Repository](https://github.com/bcgov/azure-lz-samples)
  - Location: `/tools/cicd_self_hosted_agents/`

### Pre-requisites for Self-Hosted Runners
Important considerations before deployment:
1. Specific subnet requirements must be met
2. If deploying runners in a different subscription (e.g., Tools subscription):
   - Submit firewall request to Public Cloud team
   - Request must specify need for self-hosted runners to access resources across subscriptions

## Reference Resources
- [BC Government Public Cloud Tech Docs](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- [Azure Landing Zone Samples Repository](https://github.com/bcgov/azure-lz-samples)
- Sample implementations in `/tools/cicd_self_hosted_agents/` directory
