# Storage Blob Container with least-privilege RBAC

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = var.storage_account_name
  container_access_type = var.container_access_type
}

resource "azurerm_role_assignment" "blob_container_contributor" {
  scope                = azurerm_storage_container.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.service_principal_id
}
