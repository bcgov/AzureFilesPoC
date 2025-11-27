# Creates a Virtual Network for the environment.

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.azure_location
  resource_group_name = var.vnet_resource_group
  address_space       = var.vnet_address_space
  tags                = var.common_tags
}
