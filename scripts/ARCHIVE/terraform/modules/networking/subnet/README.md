# BC Government Subnet Module

This module creates subnets in compliance with BC Government policies, particularly the requirement for NSG associations.

## Features
- Creates policy-compliant subnets using AzAPI provider
- Automatically associates NSGs
- Supports service endpoints
- Implements BC Gov security controls

## Usage
```hcl
module "subnet" {
  source = "../../modules/networking/subnet"

  subnet_name         = "snet-storage-dev"
  vnet_name          = module.vnet.name
  resource_group_name = azurerm_resource_group.rg.name
  address_prefixes    = ["10.0.1.0/24"]
  
  # Additional variables as needed
}
```

## Requirements
- AzureRM and AzAPI providers
- BC Gov Landing Zone access
- Proper RBAC permissions

## Variables
See `variables.tf` for details.
