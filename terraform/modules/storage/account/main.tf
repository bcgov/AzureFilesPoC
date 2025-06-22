# Creates a standard, secure Azure Storage Account.

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  tags                     = var.tags

  # Standard configuration for Azure Files
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"

  # Enforces security and policy compliance by default.
  public_network_access_enabled = false
}