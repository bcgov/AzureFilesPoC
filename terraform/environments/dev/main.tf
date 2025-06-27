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

#================================================================================
# STEP: CREATE RESOURCE GROUP
# RESOURCE TYPE:  azurerm_resource_group
# SCRIPT:  terraform/modules/core/resource-group/main.tf
# STATUS:  Working successful workflow creating storage account with role assignments
#================================================================================
module "poc_resource_group" {
   source = "../../modules/core/resource-group"

   resource_group_name       = var.dev_resource_group
   location                 = var.azure_location
   tags                     = var.common_tags
   service_principal_id      = var.dev_service_principal_id
}

#================================================================================
# STEP: CREATE/UPDATE THE STORAGE ACCOUNT
# RESOURCE TYPE:  azurerm_storage_account
# SCRIPT:  terraform/modules/storage/account/main.tf
# STATUS:  Working successful workflow creating storage account with role assignments
#================================================================================
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
# STEP: CREATE THE FILE SHARE 
# RESOURCE TYPE:  azurerm_storage_file_share
# SCRIPT:  terraform/modules/storage/file-share/main.tf
# STATUS:  failing with 403 error
#         Error: checking for existing File Share "fspoc-xxxx" (Account "Account \"stagxxxx\" 
#        (IsEdgeZone false / ZoneName \"\" / Subdomain Type \"file\" / DomainSuffix \"core.windows.net\")"): 
#        executing request: unexpected status 403 (403 This request is not authorized to perform this operation.) with AuthorizationFailure: This request is not authorized to perform this operation.
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
}

#================================================================================
# NEXT STEPS: RECOMMENDED RESOURCES TO CREATE FOR AZURE FILES POC
#================================================================================
# The following sections are scaffolds for the next resources you may need to test or provision.
# Uncomment and complete as needed for your PoC and BC Gov policy compliance.

#================================================================================
# STEP: CREATE THE STORAGE BLOB CONTAINER
# RESOURCE TYPE:  azurerm_storage_container
# SCRIPT:  terraform/modules/storage/blob-container/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "poc_blob_container" {
#   source = "../../modules/storage/blob-container"
#   storage_account_name    = module.poc_storage_account.name
#   container_name          = var.dev_blob_container_name
#   container_access_type   = "private"
#   service_principal_id    = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE THE STORAGE MANAGEMENT POLICY (BLOB LIFECYCLE)
# RESOURCE TYPE:  azurerm_storage_management_policy
# SCRIPT:  terraform/modules/storage/management-policy/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "poc_storage_management_policy" {
#   source = "../../modules/storage/management-policy"
#   storage_account_id      = module.poc_storage_account.id
#   policy                  = var.dev_storage_management_policy
#   service_principal_id    = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE THE PRIVATE ENDPOINT FOR STORAGE ACCOUNT
# RESOURCE TYPE:  azurerm_private_endpoint
# SCRIPT:  terraform/modules/networking/private-endpoint/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "storage_private_endpoint" {
#   source = "../../modules/networking/private-endpoint"
#   name                     = "pe-${module.poc_storage_account.name}"
#   resource_group_name      = var.dev_resource_group
#   location                 = var.azure_location
#   tags                     = var.common_tags
#   subnet_id                = module.private_endpoint_subnet.id
#   private_connection_resource_id = module.poc_storage_account.id
#   subresource_names        = ["file", "blob"]
# }

#================================================================================
# STEP: CREATE THE PRIVATE DNS ZONE & LINK
# RESOURCE TYPE:  azurerm_private_dns_zone, azurerm_private_dns_zone_virtual_network_link
# SCRIPT:  terraform/modules/networking/private-dns/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "private_dns_zone" {
#   source = "../../modules/networking/private-dns"
#   dns_zone_name         = var.dev_private_dns_zone_name
#   resource_group_name   = var.dev_resource_group
#   vnet_link_name        = var.dev_private_dns_vnet_link_name
#   virtual_network_id    = var.dev_virtual_network_id
#   registration_enabled  = false
#   tags                  = var.common_tags
#   service_principal_id  = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE THE ROUTE TABLE & ROUTES (UDR)
# RESOURCE TYPE:  azurerm_route_table, azurerm_route
# SCRIPT:  terraform/modules/networking/route-table/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "route_table" {
#   source = "../../modules/networking/route-table"
#   route_table_name      = var.dev_route_table_name
#   resource_group_name   = var.dev_resource_group
#   location              = var.azure_location
#   tags                  = var.common_tags
#   service_principal_id  = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE THE VIRTUAL NETWORK GATEWAY (VPN/EXPRESSROUTE)
# RESOURCE TYPE:  azurerm_virtual_network_gateway, azurerm_express_route_gateway
# SCRIPT:  terraform/modules/networking/vnet-gateway/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "vnet_gateway" {
#   source = "../../modules/networking/vnet-gateway"
#   vnet_gateway_name     = var.dev_vnet_gateway_name
#   resource_group_name   = var.dev_resource_group
#   location              = var.azure_location
#   gateway_type          = var.dev_gateway_type
#   vpn_type              = var.dev_vpn_type
#   sku                   = var.dev_vnet_gateway_sku
#   ip_configurations     = var.dev_vnet_gateway_ip_configurations
#   tags                  = var.common_tags
#   service_principal_id  = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE THE AZURE FIREWALL
# RESOURCE TYPE:  azurerm_firewall
# SCRIPT:  terraform/modules/networking/firewall/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "firewall" {
#   source = "../../modules/networking/firewall"
#   firewall_name         = var.dev_firewall_name
#   resource_group_name   = var.dev_resource_group
#   location              = var.azure_location
#   tags                  = var.common_tags
#   service_principal_id  = var.dev_service_principal_id
# }

#================================================================================
# STEP: CREATE AZURE FILE SYNC RESOURCES (OPTIONAL)
# RESOURCE TYPE:  azurerm_storage_sync_service, azurerm_storage_sync_group, azurerm_storage_sync_cloud_endpoint
# SCRIPT:  terraform/modules/storage/file-sync/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "file_sync" {
#   source = "../../modules/storage/file-sync"
#   sync_service_name      = var.dev_file_sync_service_name
#   resource_group_name    = var.dev_resource_group
#   location               = var.azure_location
#   tags                   = var.common_tags
#   service_principal_id   = var.dev_service_principal_id
#   # Add other required arguments for sync group, cloud endpoint, etc.
# }

#================================================================================
# STEP: MONITORING & SECURITY (DIAGNOSTICS, LOG ANALYTICS, DEFENDER)
# RESOURCE TYPE:  azurerm_monitor_diagnostic_setting, azurerm_log_analytics_workspace, azurerm_monitor_action_group, azurerm_monitor_metric_alert, azurerm_monitor_activity_log_alert, azurerm_defender_for_cloud
# SCRIPT:  terraform/modules/monitoring/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "monitoring" {
#   source = "../../modules/monitoring"
#   log_analytics_workspace_name = var.dev_log_analytics_workspace_name
#   resource_group_name          = var.dev_resource_group
#   location                    = var.azure_location
#   tags                        = var.common_tags
#   service_principal_id         = var.dev_service_principal_id
#   # Add other required arguments for diagnostics, alerts, etc.
# }

#================================================================================
# STEP: (OPTIONAL) AUTOMATION, POWER BI, CUSTOM DASHBOARDS
# RESOURCE TYPE:  azurerm_automation_account, azurerm_powerbi_workspace, etc.
# SCRIPT:  terraform/modules/automation/main.tf
# STATUS:  scaffolded, not yet implemented
#================================================================================
# module "automation" {
#   source = "../../modules/automation"
#   automation_account_name = var.dev_automation_account_name
#   resource_group_name     = var.dev_resource_group
#   location                = var.azure_location
#   tags                    = var.common_tags
#   service_principal_id    = var.dev_service_principal_id
#   # Add other required arguments for runbooks, etc.
# }