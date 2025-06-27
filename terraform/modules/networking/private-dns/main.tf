# Private DNS Zone & Link with least-privilege RBAC

resource "azurerm_private_dns_zone" "main" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "main" {
  name                  = var.vnet_link_name
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.main.name
  virtual_network_id    = var.virtual_network_id
  registration_enabled  = var.registration_enabled
  tags                  = var.tags
}

resource "azurerm_role_assignment" "dns_zone_reader" {
  scope                = azurerm_private_dns_zone.main.id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id
}
