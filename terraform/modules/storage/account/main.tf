# In /terraform/modules/storage/account/main.tf

# This block is required for the module to be valid.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.azure_location
  tags                     = var.tags
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  public_network_access_enabled = false
}

resource "azurerm_private_endpoint" "storage" {
  name                = "pe-${var.storage_account_name}"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  subnet_id           = var.storage_subnet_id

  private_service_connection {
    name                           = "conn-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}