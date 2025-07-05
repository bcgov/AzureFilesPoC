# Storage Blob Container with least-privilege RBAC

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = var.storage_account_name
  container_access_type = var.container_access_type

  metadata = var.metadata # optional, map(string)
}
