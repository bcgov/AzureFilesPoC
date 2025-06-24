# Assigns a role to a principal at the resource group scope.

resource "azurerm_role_assignment" "main" {
  scope                = "/subscriptions/${var.dev_subscription_id}/resourceGroups/${var.dev_resource_group}"
  role_definition_name = var.role_definition_name
  principal_id         = var.principal_id
}
