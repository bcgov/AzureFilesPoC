terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.12.0"
    }
  }
}

# Storage NSG Module
#
# This module creates a Network Security Group (NSG) with security rules for storage subnet
# and creates the subnet with NSG association using AzAPI for BC Gov policy compliance.
# 
# BC Gov Policy Requirement: Subnets must have NSG association at creation time
# Solution: Create NSG first, then use AzAPI to create subnet with NSG association
#
# Example usage:
#   module "storage_nsg" {
#     source              = "../../modules/storage/nsg"
#     resource_group_name = var.resource_group_name
#     location            = var.azure_location
#     nsg_name            = var.nsg_name
#     tags                = var.tags
#     vnet_id             = var.vnet_id
#     address_prefix      = var.address_prefix
#     subnet_name         = var.subnet_name
#   }

variable "resource_group_name" {
  description = "The name of the resource group where the NSG will be created."
  type        = string
}

variable "location" {
  description = "The Azure location where the NSG will be created."
  type        = string
}

variable "nsg_name" {
  description = "The name of the Network Security Group."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the NSG."
  type        = map(string)
}

variable "vnet_id" {
  description = "The ID of the Virtual Network where the storage subnet will be created."
  type        = string
}

variable "address_prefix" {
  description = "The address prefix to use for the storage subnet."
  type        = string
}

variable "subnet_name" {
  description = "The name to use for the storage subnet."
  type        = string
}

# Network Security Group for Storage Subnet
resource "azurerm_network_security_group" "storage" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Default storage subnet security rules
  # These rules allow private endpoint traffic and Azure service communication

  # Allow inbound traffic from VNet for private endpoints
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow outbound traffic to VNet for private endpoints
  security_rule {
    name                       = "AllowVNetOutbound"
    priority                   = 105
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow outbound traffic to Azure Storage service
  security_rule {
    name                       = "AllowStorageOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Storage"
  }

  # Allow outbound traffic to Azure services (for monitoring, etc.)
  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  # Allow outbound internet access for Azure services
  security_rule {
    name                       = "AllowInternetOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

# Storage Subnet with NSG Association (BC Gov Policy Compliant)
# Uses AzAPI to create subnet with NSG association in a single operation
resource "azapi_resource" "storage_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = var.vnet_id
  body = jsonencode({
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.storage.id
      }
      # Enable private endpoint network policies
      privateEndpointNetworkPolicies = "Enabled"
      # Disable private link service network policies (not needed for storage)
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  })
}

# Outputs
output "storage_nsg_id" {
  description = "The ID of the storage Network Security Group."
  value       = azurerm_network_security_group.storage.id
}

output "storage_subnet_id" {
  description = "The ID of the storage subnet."
  value       = azapi_resource.storage_subnet.id
}

output "storage_subnet_name" {
  description = "The name of the storage subnet."
  value       = var.subnet_name
}
