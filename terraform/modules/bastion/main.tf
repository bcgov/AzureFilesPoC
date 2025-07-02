variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "vnet_resource_group" { type = string }
variable "bastion_name" { type = string }
variable "public_ip_name" { type = string }
variable "address_prefix" { type = string }
variable "network_security_group" {
  description = "The name of the NSG to associate with the Bastion subnet."
  type        = string
}

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

resource "azurerm_public_ip" "bastion" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "bastion" {
  name                = var.network_security_group
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = {
    environment = "bastion"
    managed_by  = "terraform"
  }

  # Required Bastion rules (per Microsoft and BC Gov landing zone policy)
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
    description                = "Allow Azure Bastion GatewayManager inbound."
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Allow AzureLoadBalancer inbound for Bastion."
  }

  security_rule {
    name                       = "AllowBastionHostOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
    description                = "Allow Bastion outbound to Internet."
  }

  # Common BC Gov/landing zone policy: Deny all inbound except required
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other inbound traffic."
  }

  # Common BC Gov/landing zone policy: Deny all outbound except required
  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 4096
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Deny all other outbound traffic."
  }
}

# Use AzAPI to create the Bastion subnet and associate the NSG at creation time (policy compliant)
resource "azapi_resource" "bastion_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = "AzureBastionSubnet"
  parent_id = data.azurerm_virtual_network.vnet.id
  body = jsonencode({
    properties = {
      addressPrefix = var.address_prefix
      networkSecurityGroup = {
        id = azurerm_network_security_group.bastion.id
      }
    }
  })
}

resource "azurerm_bastion_host" "main" {
  name                = var.bastion_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_name            = null
  sku                 = "Standard"
  ip_configuration {
    name                 = "configuration"
    subnet_id            = azapi_resource.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

output "bastion_host_id" {
  value = azurerm_bastion_host.main.id
}
output "bastion_host_name" {
  value = azurerm_bastion_host.main.name
}
output "bastion_public_ip" {
  value = azurerm_public_ip.bastion.ip_address
}
output "bastion_subnet_id" {
  description = "The resource ID of the AzureBastionSubnet."
  value       = azapi_resource.bastion_subnet.id
}
output "bastion_nsg_id" {
  value = azurerm_network_security_group.bastion.id
}

terraform {
  # AzAPI provider is required in this module to create the Bastion subnet with NSG association in a single step (policy compliance).
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.12.0"
    }
  }
}
