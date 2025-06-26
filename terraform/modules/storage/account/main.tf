# In /terraform/modules/storage/account/main.tf

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  # Standard configuration
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"

  # --- Security Best Practices ---

  # Enforces a minimum TLS version for all connections.
  min_tls_version = "TLS1_2"

  # THIS IS THE FIX for the Azure Policy error.
  # It disables public access at the network level for the entire account.
  public_network_access_enabled = false

  #================================================================================
  # THIS IS THE NEW LINE YOU ASKED FOR, with the correct syntax.
  # This provides a second layer of security, preventing anonymous access to blobs
  # even if a container is misconfigured. It is highly recommended.
  #================================================================================
  allow_blob_public_access = false
}