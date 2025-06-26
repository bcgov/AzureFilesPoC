# In /terraform/modules/storage/account/main.tf

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  large_file_share_enabled          = true
  access_tier                       = "Hot"
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public = false

  # --- CHANGE THIS BLOCK ---
  # Enable public access so we can configure the firewall.
  public_network_access_enabled = true

  # Add this block to control access via a firewall.
  network_rules {
    # This is the most important setting. It blocks everything by default.
    default_action             = "Deny"
    # This allows other Azure services to connect.
    bypass                     = ["AzureServices"]
    # This will be populated by a variable from our GitHub Action.
    ip_rules                   = var.allowed_ip_rules
    # We aren't using VNet rules yet, so this is empty.
    virtual_network_subnet_ids = []
  }
}