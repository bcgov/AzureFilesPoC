# Creates a Virtual Network for the environment.

resource "azurerm_virtual_network" "main" {
  name                = var.dev_vnet_name
  location            = var.dev_location
  resource_group_name = var.dev_vnet_resource_group
  address_space       = var.dev_vnet_address_space
  tags                = var.common_tags
}
