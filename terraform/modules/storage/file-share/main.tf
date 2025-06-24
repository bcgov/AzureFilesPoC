# Creates an Azure File Share within a specified Storage Account.

resource "azurerm_storage_share" "main" {
  name                 = var.file_share_name
  storage_account_name = var.storage_account_name
  quota                = var.quota_gb
  enabled_protocol     = var.enabled_protocol
  metadata             = var.metadata
}
