# Creates an Azure Key Vault using project naming conventions and external resource group context.

resource "azurerm_key_vault" "main" {
  name                        = var.dev_keyvault_name
  location                    = var.dev_location
  resource_group_name         = var.dev_resource_group
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.sku_name
  soft_delete_enabled         = true
  purge_protection_enabled    = true
  enabled_for_disk_encryption = true
  tags                       = var.common_tags
}

data "azurerm_client_config" "current" {}
