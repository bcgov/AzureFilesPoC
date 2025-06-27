# Storage Management Policy (Blob Lifecycle) with least-privilege RBAC

resource "azurerm_storage_management_policy" "main" {
  storage_account_id = var.storage_account_id
  policy             = var.policy
}

resource "azurerm_role_assignment" "management_policy_reader" {
  scope                = azurerm_storage_management_policy.main.id
  role_definition_name = "Reader"
  principal_id         = var.service_principal_id
}
