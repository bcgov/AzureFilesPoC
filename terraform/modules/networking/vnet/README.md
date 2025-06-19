# BC Government Virtual Network Module

This module creates and configures Virtual Networks in compliance with BC Government requirements.

## Features
- Creates Hub and Spoke VNets
- Configures VNet peering
- Implements BC Gov naming conventions and tags
- Supports multiple environments

## Usage
```hcl
module "vnet" {
  source = "../../modules/networking/vnet"

  vnet_name         = "vnet-azurefiles-dev"
  resource_group_name = azurerm_resource_group.rg.name
  location          = var.location
  address_space     = ["10.0.0.0/16"]
  
  # Additional variables as needed
}
```

## Requirements
- AzureRM provider
- BC Gov Landing Zone access
- Proper RBAC permissions

## Variables
See `variables.tf` for details.
