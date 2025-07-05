# terraform/modules/storage/account/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# This module correctly creates ONLY a private-only Azure Storage Account.
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.azure_location
  tags                     = var.tags

  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  # This setting is the key to complying with BC Gov policy.
  public_network_access_enabled = false
}