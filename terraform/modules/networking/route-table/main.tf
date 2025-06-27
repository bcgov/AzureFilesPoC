# Route Table with least-privilege RBAC

resource "azurerm_route_table" "main" {
  name                = var.route_table_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "route_table_reader" {
  scope                = azurerm_route_table.main.id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id
}
