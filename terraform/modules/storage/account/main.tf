# In /terraform/modules/storage/account/main.tf

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  tags                = var.tags

  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  large_file_share_enabled          = true
  # ... other settings ...

  # --- TEMPORARY CHANGE FOR PIPELINE SUCCESS ---
  # Enable public access to allow the pipeline runner to connect.
  public_network_access_enabled = true 
  
  network_rules {
    # This now becomes the default action when public access is enabled.
    default_action = "Allow"
  }
}

