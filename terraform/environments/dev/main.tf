# --- terraform/environments/dev/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'dev' environment.
# This version is structured to troubleshoot the 403 network/permission error.

terraform {
  required_version = ">= 1.6.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }

  backend "azurerm" {
    key = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

#1.  TEST 1:  TRY to create the resource group only
# This is a simple test to ensure the provider and backend are working.
# module "poc_resource_group" {
#   source = "../../modules/core/resource-group"
#
#   resource_group_name       = var.dev_resource_group_b
#   location                 = var.azure_location
#   tags                     = var.common_tags
#   service_principal_id      = var.dev_service_principal_id
# }

#================================================================================
# STEP 1: CREATE/UPDATE THE STORAGE ACCOUNT
#================================================================================
# This runs first, ensuring the storage account exists with the correct
# network configuration before any other resource tries to interact with it.
#STATUS:  Working successful workflow creating storage account with role assignments

module "poc_storage_account" {
  source = "../../modules/storage/account"

  storage_account_name = var.dev_storage_account_name
  resource_group_name  = var.dev_resource_group
  location             = var.azure_location
  tags                 = var.common_tags

  # Pass the runner's IP address to the module so it can create a firewall rule.
  allowed_ip_rules = var.allowed_ip_rules
  service_principal_id = var.dev_service_principal_id
}


#================================================================================
# STEP 2: CREATE THE FILE SHARE (RUNS LAST)
#================================================================================
# Create the file share in the storage account.
module "poc_file_share" {
  source = "../../modules/storage/file-share"

  # --- Required Arguments ---
  file_share_name      = var.dev_file_share_name
  storage_account_name = module.poc_storage_account.name
  quota_gb             = var.dev_file_share_quota_gb

  # --- Optional Arguments ---
  enabled_protocol = "SMB"
  access_tier      = "TransactionOptimized"
  metadata         = {}

  # The 'depends_on' block now ensures this runs absolutely last, after the
  # role has been assigned AND the wait time has passed.
  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]
}

#================================================================================
# COMMENTED OUT RESOURCES FOR FUTURE USE
#================================================================================

# # Use the subnet module to create the dedicated subnet in the existing VNet.
# module "private_endpoint_subnet" {
#    source = "../../modules/networking/subnet"
#
#    subnet_name              = var.dev_subnet_name
#    resource_group_name      = var.dev_vnet_resource_group
#    location                 = var.azure_location
#    vnet_name                = var.dev_vnet_name
#    vnet_resource_group_name = var.dev_vnet_resource_group
#    address_prefixes         = var.dev_subnet_address_prefixes
#    tags                     = var.common_tags
# }
#
# # Use the private endpoint module to connect the storage account to the subnet.
# module "storage_private_endpoint" {
#    source = "../../modules/networking/private-endpoint"
#
#    name                     = "pe-${module.poc_storage_account.name}"
#    resource_group_name      = var.dev_resource_group
#    location                 = var.azure_location
#    tags                     = var.common_tags
#
#    subnet_id                = module.private_endpoint_subnet.id
#    private_connection_resource_id = module.poc_storage_account.id
#    subresource_names        = ["file", "blob"]
# }