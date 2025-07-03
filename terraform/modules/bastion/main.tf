# Bastion Host Module
#
# Assumptions / Constraints:
# - This module does NOT create the Bastion subnet or its NSG.
# - The Bastion subnet (typically "AzureBastionSubnet") must already exist and be policy-compliant (created with NSG association).
# - The NSG must be created and associated with the subnet before using this module.
# - The subnet ID must be provided to this module (e.g., via output from the subnet/NSG module).
# - The public IP must be created by this module or provided as an input.
# - This module is intended for use in environments where strict Azure Policy requires NSG association at subnet creation.

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "vnet_name" { type = string }
variable "vnet_resource_group" { type = string }
variable "bastion_name" { type = string }
variable "public_ip_name" { type = string }
variable "subnet_id" { type = string }

resource "azurerm_public_ip" "bastion" {
  name                = var.public_ip_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = var.bastion_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  dns_name            = null
  sku                 = "Standard"
  tunneling_enabled   = true  # Enable native client support for Azure CLI SSH
  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.subnet_id
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
