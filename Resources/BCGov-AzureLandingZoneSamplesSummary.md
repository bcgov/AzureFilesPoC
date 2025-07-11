# BC Gov Azure Landing Zone Samples: Key Takeaways and Alignment

## Overview

The [bcgov/azure-lz-samples](https://github.com/bcgov/azure-lz-samples) repository provides reference Terraform modules and sample code for deploying common Azure Landing Zone (LZ) components in BC Government environments. These samples are designed to align with BC Gov policy, leverage Azure Verified Modules (AVM), and support secure, modular, and policy-compliant infrastructure-as-code practices.

## Key Features and Best Practices from the Samples

- **Modular AVM Usage:** Each major component (Bastion, self-hosted runners, DevOps pools, Cloud Shell in VNet) is implemented as a standalone, reusable Terraform module, using AVM where possible.
- **Ephemeral Runners:** The samples favor container-based (ephemeral) self-hosted runners for CI/CD, which are more cost-effective and secure than persistent VMs.
- **Policy Alignment:** All modules assume an existing VNet (from Project Set) and require external provisioning of Terraform state storage. Subnets, NSGs, and delegations are created by the modules, with correct address prefixes and service delegations.
- **OIDC Authentication:** OIDC is the default for all modules, ensuring secure, passwordless authentication.
- **Known Issues and Policy Quirks:** Each module documents known issues, especially around DNS, IAM, and resource group deletion, and provides workarounds for BC Gov policy edge cases.
- **Provider and Version Requirements:** The samples require recent versions of Terraform and providers (Terraform >= 1.9, azurerm ~> 4.0, azapi ~> 2.0).

## Alignment and Recommendations for This Project

- Our project is well-aligned with the Landing Zone samples in terms of policy, OIDC, and secure networking.
- The samples offer more modularity and AVM adoption, and their container-based runner approach is recommended for future enhancements.
- For new infrastructure, consider:
  - Refactoring modules to use AVM where possible
  - Adopting ephemeral/container-based runners for CI/CD
  - Following their subnet/NSG/delegation patterns
  - Using their Cloud Shell in VNet and DevOps pool modules if those features are needed
- Reference their README "Known Issues" sections for policy and automation tips.

## Reference

- [bcgov/azure-lz-samples GitHub Repository](https://github.com/bcgov/azure-lz-samples)

These samples are a strong resource for future-proofing and policy compliance in BC Gov Azure environments. Consider reviewing them before starting new infrastructure work or major refactoring.
