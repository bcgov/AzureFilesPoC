terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.12.0"
    }
  }
}

# Runner NSG and Subnet Module
# This module creates a Network Security Group (NSG) for the runner and a subnet with the NSG assigned at creation (AzAPI).

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "nsg_name" { type = string }
variable "tags" { type = map(string) }
variable "vnet_id" { type = string }
variable "address_prefix" { type = string }
variable "subnet_name" { type = string }

resource "azurerm_network_security_group" "runner" {
  name                = var.nsg_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Inbound: Deny all by default (no inbound rules)
  # Uncomment below to allow SSH from a specific admin IP/CIDR for troubleshooting only
  # security_rule {
  #   name                       = "AllowSSHFromAdmin"
  #   priority                   = 100
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "Tcp"
  #   source_port_range          = "*"
  #   destination_port_range     = "22"
  #   source_address_prefix      = var.ssh_allowed_cidr
  #   destination_address_prefix = "*"
  # }

  # Outbound: Allow HTTPS to Internet (for GitHub, updates, etc.)
  security_rule {
    name                       = "AllowOutboundHTTPS"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  # Outbound: Allow HTTP to Internet (optional, for package downloads, etc.)
  security_rule {
    name                       = "AllowOutboundHTTP"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azapi_resource" "runner_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = var.vnet_id
  body = jsonencode({
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.runner.id
      }
    }
  })
}

output "runner_nsg_id" {
  value = azurerm_network_security_group.runner.id
}

output "runner_subnet_id" {
  value = azapi_resource.runner_subnet.id
}
