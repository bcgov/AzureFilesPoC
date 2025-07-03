# Azure Firewall with least-privilege RBAC

resource "azurerm_firewall" "main" {
  name                = var.firewall_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  tags                = var.tags
}

resource "azurerm_role_assignment" "firewall_reader" {
  scope                = azurerm_firewall.main.id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id
}
