# Terraform Module Structure for Azure Files PoC

## Overview
This document outlines the modular Terraform structure needed to implement the Azure Files PoC architecture in compliance with BC Government requirements.

## Module Organization

### 1. Networking Modules
Required for implementing the hub-and-spoke network topology:

#### VNet Module (`modules/networking/vnet`)
- Hub and Spoke VNet creation
- VNet peering configuration
- Tags and naming convention compliance

#### Subnet Module (`modules/networking/subnet`)
- BC Gov compliant subnet creation with NSG
- Uses AzAPI provider for policy compliance
- Service endpoint configuration

#### Private Endpoint Module (`modules/networking/private-endpoint`)
- Private endpoint configuration
- Integration with private DNS zones
- Network policies

### 2. Storage Modules
Core storage components for the PoC:

#### Storage Account Module (`modules/storage/account`)
- Storage account configuration
- Security settings
- Network rules and firewall configuration

#### File Share Module (`modules/storage/file-share`)
- Azure Files share creation
- Performance tier configuration
- Access policies

#### Blob Storage Module (`modules/storage/blob`)
- Blob container creation
- Lifecycle management policies
- Access tier configuration

### 3. Security Modules
Security components required by BC Government:

#### NSG Module (`modules/security/nsg`)
- Network Security Group rules
- Security logging configuration
- Standard security rules

#### Firewall Module (`modules/security/firewall`)
- Azure Firewall configuration
- Rule collections
- Logging settings

### 4. DNS Modules
DNS components for hybrid connectivity:

#### Private DNS Module (`modules/dns/private-dns`)
- Private DNS zone creation
- Virtual network links
- DNS records

#### DNS Resolver Module (`modules/dns/resolver`)
- Azure Private DNS Resolver configuration
- Forwarding rules
- Inbound/Outbound endpoints

## Usage Example

```hcl
# environments/dev/main.tf
module "vnet" {
  source = "../../modules/networking/vnet"
  
  vnet_name = "vnet-azurefiles-dev"
  # ... other variables
}

module "storage" {
  source = "../../modules/storage/account"
  
  storage_account_name = "saazurefilesdev001"
  # ... other variables
}

module "private_endpoint" {
  source = "../../modules/networking/private-endpoint"
  
  endpoint_name = "pe-azurefiles-dev"
  subnet_id     = module.vnet.subnet_id
  # ... other variables
}
```

## BC Government Specific Requirements

### 1. Resource Naming
All modules should implement BC Government naming conventions:
- Resource type prefixes
- Environment indicators
- Numbering schemes

### 2. Required Tags
All resources must include mandatory BC Government tags:
- Project
- Environment
- Classification
- Service owner

### 3. Security Controls
Modules must implement:
- Mandatory NSG associations
- Private endpoint configurations
- Network isolation

### 4. Policy Compliance
Modules should use:
- AzAPI provider for policy-compliant subnet creation
- Lifecycle blocks for policy-managed resources
- Compliant network configurations

## Best Practices

1. **Module Independence**
   - Each module should be self-contained
   - Use variables for all configurable values
   - Provide meaningful outputs

2. **Version Control**
   - Use semantic versioning for modules
   - Document breaking changes
   - Maintain backwards compatibility where possible

3. **Documentation**
   - README for each module
   - Input/output variable documentation
   - Usage examples

4. **Testing**
   - Test modules in isolation
   - Validate BC Gov compliance
   - Check resource creation order

## Reference Resources
- [BC Government Module Examples](https://github.com/bcgov/azure-lz-terraform-modules)
- [Azure Landing Zone Requirements](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/bc-govs-azure-landing-zone-overview/)
- [BC Government IaC Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
