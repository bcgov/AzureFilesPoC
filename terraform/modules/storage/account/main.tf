# In /terraform/modules/storage/account/main.tf

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"
  
  # This is the line that fixes the Azure Policy error
  public_network_access_enabled = false
}