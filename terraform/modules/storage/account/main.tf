# In /terraform/modules/storage/account/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  tags                = var.tags

  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  # This is the ONLY setting needed to signal a private-only account.
  public_network_access_enabled = false

  # The 'network_rules' block has been COMPLETELY REMOVED. Its presence
  # was sending a conflicting signal to the Azure API, causing the
  # 'RequestDisallowedByPolicy' error.
}