# --- terraform/environments/dev/main.tf ---

terraform {
  required_version = ">= 1.6.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    azapi   = { source = "azure/azapi", version = "~> 1.0" }
    time    = { source = "hashicorp/time", version = ">= 0.9.1" }
  }
  backend "azurerm" { key = "dev.terraform.tfstate" }
}

provider "azurerm" {
  features {}
}

provider "azapi" {
  # AzAPI provider for BC Gov policy-compliant resources
}

#================================================================================
# SECTION 1: DATA SOURCES
#================================================================================

data "azurerm_resource_group" "main" {
  name = var.resource_group
}

data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

data "azurerm_subnet" "runner" {
  name                 = var.runner_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group
}

#================================================================================
# SECTION 2: CORE INFRASTRUCTURE
#================================================================================

# This module creates the storage subnet and its required NSG.
module "storage_nsg" {
  source              = "../../modules/storage/nsg"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  nsg_name            = var.storage_network_security_group
  tags                = var.common_tags
  vnet_id             = data.azurerm_virtual_network.spoke_vnet.id
  address_prefix      = var.storage_subnet_address_prefix[0]
  subnet_name         = var.storage_subnet_name
}

# --- UPDATED MODULE CALL ---
# This module now creates BOTH the storage account and its private endpoint.
# We pass in the storage_subnet_id from the module above to enable this.
module "poc_storage_account" {
  source               = "../../modules/storage/account"
  storage_account_name = var.storage_account_name
  resource_group_name  = data.azurerm_resource_group.main.name
  azure_location       = var.azure_location
  tags                 = var.common_tags
  service_principal_id = var.service_principal_id
  
  # Pass the storage subnet ID into the module for Private Endpoint creation.
  storage_subnet_id    = module.storage_nsg.storage_subnet_id

  depends_on = [
    module.storage_nsg
  ]
}

# The 'storage_private_endpoint' module has been COMPLETELY REMOVED.
# Its functionality is now handled inside the 'poc_storage_account' module
# to satisfy the strict Azure Policy for simultaneous resource creation.

#================================================================================
# SECTION 2.4: PRIVATE DNS ZONE (REMOVED)
#================================================================================
# The 'private_dns_zone' module was correctly removed previously to align with
# the BC Government Azure Landing Zone documentation, which states that Private
# DNS is a centralized, platform-managed service. The platform will automatically
# create the required A-record for the private endpoint.
#================================================================================

#================================================================================
# SECTION 2.4.1: DATA PLANE ROLE ASSIGNMENT AND DELAY
#================================================================================
resource "azurerm_role_assignment" "storage_data_contributor_for_files" {
  role_definition_name = "Storage File Data SMB Share Contributor"
  scope                = module.poc_storage_account.id
  principal_id         = var.service_principal_id
}

resource "time_sleep" "wait_for_role_propagation" {
  create_duration = "45s"
  triggers        = { role_assignment_id = azurerm_role_assignment.storage_data_contributor_for_files.id }
}

#================================================================================
# SECTION 3: DATA PLANE RESOURCES
#================================================================================
module "poc_file_share" {
  source               = "../../modules/storage/file-share"
  depends_on           = [time_sleep.wait_for_role_propagation]
  file_share_name      = var.file_share_name
  storage_account_name = module.poc_storage_account.name
  quota_gb             = 10
  service_principal_id = var.service_principal_id
  enabled_protocol     = "SMB"
  access_tier          = "Hot"
  metadata             = {
    env            = "dev"
    project        = var.common_tags["project"]
    owner          = var.common_tags["owner"]
    account_coding = var.common_tags["account_coding"]
    billing_group  = var.common_tags["billing_group"]
    ministry_name  = var.common_tags["ministry_name"]
  }
}

# --------------------------------------------------------------------------------
# 3.2 (Optional) Blob Container
# --------------------------------------------------------------------------------
# module "poc_blob_container" {
#   source = "../../modules/storage/blob-container"
#   storage_account_name    = module.poc_storage_account.name
#   container_name          = var.blob_container_name
#   container_access_type   = "private"
#   service_principal_id    = var.service_principal_id
# }

# --------------------------------------------------------------------------------
# 3.3 (Optional) Storage Management Policy
# --------------------------------------------------------------------------------
# module "poc_storage_management_policy" {
#   source = "../../modules/storage/management-policy"
#   storage_account_id      = module.poc_storage_account.id
#   policy                  = var.storage_management_policy
#   service_principal_id    = var.service_principal_id
# }

#================================================================================
# SECTION 4: MONITORING, AUTOMATION, FILE SYNC (OPTIONAL)
#================================================================================
# 4.1 (Optional) Azure File Sync
# 4.2 (Optional) Monitoring & Security
# 4.3 (Optional) Automation, Power BI, Custom Dashboards

# --------------------------------------------------------------------------------
# 4.1 (Optional) Azure File Sync
# --------------------------------------------------------------------------------
# module "file_sync" {
#   source = "../../modules/storage/file-sync"
#   sync_service_name      = var.file_sync_service_name
#   resource_group_name    = var.resource_group
#   location               = var.azure_location
#   tags                   = var.common_tags
#   service_principal_id   = var.service_principal_id
#   # Add other required arguments for sync group, cloud endpoint, etc.
# }

# --------------------------------------------------------------------------------
# 4.2 (Optional) Monitoring & Security
# --------------------------------------------------------------------------------
# module "monitoring" {
#   source = "../../modules/monitoring"
#   log_analytics_workspace_name = var.log_analytics_workspace_name
#   resource_group_name          = var.resource_group
#   location                    = var.azure_location
#   tags                        = var.common_tags
#   service_principal_id         = var.service_principal_id
#   # Add other required arguments for diagnostics, alerts, etc.
# }

# --------------------------------------------------------------------------------
# 4.3 (Optional) Automation, Power BI, Custom Dashboards
# --------------------------------------------------------------------------------
# module "automation" {
#   source = "../../modules/automation"
#   automation_account_name = var.automation_account_name
#   resource_group_name     = var.resource_group
#   location                = var.azure_location
#   tags                    = var.common_tags
#   service_principal_id    = var.service_principal_id
#   # Add other required arguments for runbooks, etc.
# }