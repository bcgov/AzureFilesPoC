# Creates a standard, secure Azure Storage Account.

resource "azurerm_storage_account" "main" {
  # --- Required Arguments ---
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # --- Standard Configuration for Azure Files ---
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"

  #================================================================================
  # THIS IS THE FIX for the "RequestDisallowedByPolicy" error.
  # This line explicitly tells Azure to create the storage account without a
  # public IP address, which makes it compliant with your organization's policy.
  #================================================================================
  public_network_access_enabled = false
}