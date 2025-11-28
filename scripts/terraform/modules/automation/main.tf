# Automation Account with least-privilege RBAC

resource "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"
  tags                = var.tags
}

resource "azurerm_role_assignment" "automation_operator" {
  scope                = azurerm_automation_account.main.id
  role_definition_name = "Automation Operator"
  principal_id         = var.service_principal_id
}
