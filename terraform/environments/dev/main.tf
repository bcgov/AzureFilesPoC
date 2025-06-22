# --- terraform/environments/dev/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'dev' environment.

provider "azurerm" {
  features {}
}

# 1. Create a dedicated Resource Group for the PoC services.
resource "azurerm_resource_group" "poc_rg" {
  name     = var.dev_resource_group
  location = var.dev_location
  tags     = var.common_tags
}

# 2. Use the subnet module to create the dedicated subnet in the existing VNet.
module "private_endpoint_subnet" {
  source = "../../modules/networking/subnet"

  subnet_name              = var.dev_subnet_name
  resource_group_name      = var.dev_vnet_resource_group
  location                 = var.dev_location
  vnet_name                = var.dev_vnet_name
  vnet_resource_group_name = var.dev_vnet_resource_group
  address_prefixes         = var.dev_subnet_address_prefixes
  tags                     = var.common_tags
}

# 3. Use the storage module to create the secure storage account.
module "poc_storage_account" {
  source = "../../modules/storage/account"

  storage_account_name = var.dev_storage_account_name
  resource_group_name  = azurerm_resource_group.poc_rg.name
  location             = azurerm_resource_group.poc_rg.location
  tags                 = var.common_tags
}

# 4. Use the private endpoint module to connect the storage account to the subnet.
module "storage_private_endpoint" {
  source = "../../modules/networking/private-endpoint"

  name                = "pe-${module.poc_storage_account.name}"
  resource_group_name = azurerm_resource_group.poc_rg.name
  location            = azurerm_resource_group.poc_rg.location
  tags                = var.common_tags

  subnet_id                    = module.private_endpoint_subnet.id
  private_connection_resource_id = module.poc_storage_account.id
  subresource_names            = ["file", "blob"]
}