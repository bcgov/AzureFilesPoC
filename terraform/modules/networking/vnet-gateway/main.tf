# Virtual Network Gateway with least-privilege RBAC

resource "azurerm_virtual_network_gateway" "main" {
  name                = var.vnet_gateway_name
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = var.gateway_type
  vpn_type            = var.vpn_type
  sku                 = var.sku
  ip_configurations   = var.ip_configurations
  tags                = var.tags
}

resource "azurerm_role_assignment" "vnet_gateway_reader" {
  scope                = azurerm_virtual_network_gateway.main.id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id
}
