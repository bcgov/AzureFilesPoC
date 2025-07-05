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
  public_network_access_enabled = false 
  
  network_rules {
    # This now becomes the default action when public access is enabled.
    default_action = "Deny"
    virtual_network_subnet_ids = [
      var.runner_subnet_id,   # <-- Add the resource ID of your runner subnet
      # var.storage_subnet_id, # Optionally, add storage subnet if needed
    ]
  }
}

