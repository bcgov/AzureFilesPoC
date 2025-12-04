# Azure Pipelines Resources for Azure Files PoC

## Overview
This document outlines the integration of Azure Pipelines with Terraform for the Azure Files PoC, focusing on BC Government-specific implementation details. For Terraform-specific details, please refer to [TerraformResourcesForAzurePoC.md](./TerraformResourcesForAzurePoC.md), and for GitHub Actions details, see [TerraformWithGithubActionsProcess.md](./TerraformWithGithubActionsProcess.md).

## Azure Pipelines Authentication

### Workload Identity Federation (OIDC)
Azure DevOps supports Workload Identity Federation, enabling secure authentication without storing credentials. This modern approach:
- Eliminates the need for service principal secrets
- Provides time-bound access tokens
- Supports fine-grained access control
- Integrates seamlessly with Azure Pipelines

For detailed implementation steps, refer to the [Azure DevOps Workload Identity Federation documentation](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/).

## Implementation Example

### Pipeline Configuration
```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: terraform-variables

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'OIDC-ServiceConnection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      # Azure CLI commands use OIDC token automatically
      az account show
```

### Service Connection Setup
1. Create new Azure Resource Manager service connection
2. Select "Workload Identity federation (manual)"
3. Configure federation subject settings per BC Gov standards

## Key Differences from GitHub Actions

1. **Authentication Flow**:
   - Native integration with Azure AD
   - Built-in support for Azure service connections
   - Simplified OIDC configuration process

2. **Security Considerations**:
   - Uses Azure DevOps-specific OIDC issuer URL
   - Different federation subject configuration
   - Integrated with Azure DevOps security model

3. **Pipeline Configuration**:
   - Uses Azure Pipeline YAML syntax
   - Supports Azure Pipeline-specific tasks
   - Different variable and secret management

## BC Government Specific Requirements

1. **Environment Requirements**:
   - Use approved BC Gov Azure DevOps organization
   - Follow BC Gov naming conventions for service connections
   - Implement required approval gates

2. **Security Standards**:
   - Mandatory OIDC authentication
   - No service principal secrets allowed
   - Compliance with BC Gov security policies

3. **Resource Access**:
   - Follow BC Gov network policies
   - Use approved service connection types
   - Implement required access controls

## Managed DevOps Pools Integration

For scenarios requiring self-hosted agents:
- Use BC Gov approved Azure Verified Module for Managed DevOps Pools
- Implementation samples available in [azure-lz-samples](https://github.com/bcgov/azure-lz-samples) repository
- Located in `/tools/cicd_managed_devops_pools/` directory

## Best Practices

1. **Pipeline Design**:
   - Use YAML-based pipeline definitions
   - Implement proper environment protection rules
   - Follow BC Gov stage gate requirements

2. **Security**:
   - Use Workload Identity Federation exclusively
   - Implement least-privilege access
   - Follow BC Gov security guidelines

3. **Resource Management**:
   - Use approved task versions
   - Implement proper error handling
   - Follow BC Gov deployment patterns

## Reference Resources
- [Azure DevOps Workload Identity Federation Documentation](https://devblogs.microsoft.com/devops/introduction-to-azure-devops-workload-identity-federation-oidc-with-terraform/)
- [BC Government Azure DevOps Guidelines](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- [Azure Landing Zone Samples](https://github.com/bcgov/azure-lz-samples)
