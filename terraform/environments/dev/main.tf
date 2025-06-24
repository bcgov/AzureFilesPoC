# --- terraform/environments/dev/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'dev' environment.

provider "azurerm" {
  features {}
}

# =================
# ASSUMPTIONS
# =================
# 1. Reference the dedicated Resource Group for the PoC services.
# NOTE: Per BC Gov policy, the resource group must be created outside of Terraform using your own identity (not by automation).
# The resource group name is provided via the DEV_RESOURCE_GROUP_NAME GitHub secret and in terraform.tfvars.
# Do NOT attempt to create or manage the resource group with Terraform.
# Example onboarding script: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh
#
# Use the existing resource group name directly in module calls below.

# 1. Create the secure storage account.
module "poc_storage_account" {
  source = "../../modules/storage/account"

  storage_account_name = var.dev_storage_account_name
  resource_group_name  = var.dev_resource_group
  location             = var.dev_location
  tags                 = var.common_tags
}

# 2. Create the file share in the storage account.
module "poc_file_share" {
  source = "../../modules/storage/file-share"

  file_share_name      = var.dev_file_share_name
  storage_account_name = module.poc_storage_account.name
  quota_gb            = var.dev_file_share_quota_gb
  enabled_protocol    = "SMB"
  metadata            = {}
  tags                = var.common_tags
}

# --- The following resources are commented out for initial setup ---

# # Use the subnet module to create the dedicated subnet in the existing VNet.
# module "private_endpoint_subnet" {
#   source = "../../modules/networking/subnet"
#
#   subnet_name              = var.dev_subnet_name
#   resource_group_name      = var.dev_vnet_resource_group
#   location                 = var.dev_location
#   vnet_name                = var.dev_vnet_name
#   vnet_resource_group_name = var.dev_vnet_resource_group
#   address_prefixes         = var.dev_subnet_address_prefixes
#   tags                     = var.common_tags
# }
#
# # Use the private endpoint module to connect the storage account to the subnet.
# module "storage_private_endpoint" {
#   source = "../../modules/networking/private-endpoint"
#
#   name                = "pe-${module.poc_storage_account.name}"
#   resource_group_name = var.dev_resource_group
#   location            = var.dev_location
#   tags                = var.common_tags
#
#   subnet_id                    = module.private_endpoint_subnet.id
#   private_connection_resource_id = module.poc_storage_account.id
#   subresource_names            = ["file", "blob"]
# }