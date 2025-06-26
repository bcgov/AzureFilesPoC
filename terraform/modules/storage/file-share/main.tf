# terraform/modules/storage/file-share/main.tf

resource "azurerm_storage_share" "main" {
  name                 = var.file_share_name
  storage_account_name = var.storage_account_name
  quota                = var.quota_gb

  # Corresponds to properties.enabledProtocols in an Azure export
  enabled_protocol = var.enabled_protocol

  # Corresponds to properties.accessTier in an Azure export
  # Common values are "Hot", "Cool", "TransactionOptimized", "Premium"
  access_tier = var.access_tier

  # Corresponds to the metadata property
  metadata = var.metadata

  # Defines file and folder-level permissions
  dynamic "acl" {
    for_each = var.acls
    content {
      id = acl.value.id
      access_policy {
        permissions = acl.value.permissions
        start       = acl.value.start
        expiry      = acl.value.expiry
      }
    }
  }
}