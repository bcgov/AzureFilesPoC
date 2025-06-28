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

# ================================================================================
# Azure Infrastructure as code (IaC Best Practices)
# -------------------------------------------------------------------------------
# KEY PRINCIPLES: 
# -------------------------------------------------------------------------------
# 1. RBAC / Least Privilege
#    - Assign roles at the lowest appropriate scope (module-level patterns).
# -------------------------------------------------------------------------------
# RESOURCE CREATION SEQUENCING
# -------------------------------------------------------------------------------
# 1. Resource Group First
#    - Always create the resource group first; all other resources depend on it.
# 2. Core Infrastructure (Networking, Storage)
#    - 2.1 Storage Account: Created early, required for file shares, blobs, policies.
#    - 2.2 Networking (recommended sequencing):
#        2.2.1 Virtual Network (VNet): Foundation for all networking resources.
#        2.2.2 Subnets: Created within the VNet for resource segmentation.
#        2.2.3 Network Security Groups (NSGs): Applied to subnets or NICs for traffic filtering.
#        2.2.4 Route Tables: Associated with subnets to control routing.
#        2.2.5 Azure Firewall: Deployed after VNet/subnets for centralized security.
#        2.2.6 Private Endpoints: Created after VNet/subnets and target resources (e.g., storage).
#        2.2.7 Private DNS Zones & Links: Created after private endpoints for name resolution.
#        2.2.8 Virtual Network Gateway: Created after VNet/subnets for VPN/ExpressRoute.
#    - Sequence: VNet → Subnets → NSGs → Route Tables → Firewall → Private Endpoints → Private DNS → VNet Gateway
#    - Rationale: Each object depends on the previous (e.g., endpoints require subnets, DNS links require endpoints, gateways require VNet/subnets).
# 3. Data Plane Resources
#    - 3.1 File Share, 
#    - 3.2 Blob Container: Created after storage account.
#    - 3.3 Management Policy: Created after storage account and blob container.
# 4. Security and Connectivity
#    - Private Endpoint: After storage/networking resources.
#    - Private DNS Zone: After private endpoint (links to endpoint & VNet).
#    - Route Table, Firewall, VNet Gateway: After core networking (depend on VNet/subnets).
# 5. Monitoring, Automation, File Sync
#    - Monitoring, Automation, File Sync: After core resources (depend on storage/networking).
# -------------------------------------------------------------------------------
# Reference: Microsoft & BC Gov Azure IaC Best Practices
# ================================================================================

#================================================================================
# SECTION summarizes all terraform resources that are currently enabled
#         and will run and be created when script executed in github
# LIST:
# 1. Resource Group (created using user identity before running this script)
# 2.9 Storage Account (enabled-confirmed working)
# 3.1 File Share (commented out)
#================================================================================

#================================================================================
# SECTION 1: CORE RESOURCE GROUP
#================================================================================
# Resource groups are pre-created by the BC Gov landing zone/central IT. 
# Service principals and Terraform are NOT authorized to create resource groups.
# Reference the pre-created resource group by name (var.dev_resource_group) in all modules.
# Look up the pre-existing resource group using a data source.
# This READS data instead of trying to CREATE (write) the resource.
# Policy seems to prevent creating resource groups with terraform and
# pipeline using an azure script using service principal IDENTITY
# options: 
# 1. create resource group in azure portal 
# 2. create resource group using azure CLI using script
#    e.g. OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh
# role assignments for subscription and or resource group required
# --------------------------------------------------------------------------------
# REQUIRED ROLE ASSIGNMENTS FOR THIS SCRIPT TO WORK:
#
# Subscription Level (assigned by step2_grant_permissions.sh):
#   - Reader
#   - Storage Account Contributor
#   - [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#   - Private DNS Zone Contributor
#   - Monitoring Contributor
#   (Assign only those truly needed at subscription scope for least privilege.)
#
# Resource Group Level (assigned by step6_create_resource_group.sh):
#   - Storage Account Contributor
#   - ag-pssg-azure-files-poc-dev-role-assignment-writer (custom role)
#
# These assignments are required for the service principal to deploy and manage
# resources in this environment. See onboarding scripts for details.
# --------------------------------------------------------------------------------
#ASSUMPTION:  This terraform script assumes the resource group exists
data "azurerm_resource_group" "main" {
  name = var.dev_resource_group
}

#================================================================================
# SECTION 2: CORE INFRASTRUCTURE (NETWORKING & STORAGE)
#================================================================================
# 2.1 Virtual Network (VNet)
# 2.2 Subnets
# 2.3 Network Security Groups (NSGs)
# 2.4 Route Tables
# 2.5 Azure Firewall (Optional)
# 2.6 Private Endpoints (Optional)
# 2.7 Private DNS Zones & Links (Optional)
# 2.8 Virtual Network Gateway (Optional)
# 2.9 Storage Account

# --------------------------------------------------------------------------------
# 2.1 (Optional) Virtual Network
# --------------------------------------------------------------------------------
# module "vnet" {
#   source = "../../modules/networking/vnet"
#   name                = var.dev_vnet_name
#   address_space       = var.dev_vnet_address_space
#   location            = var.azure_location
#   resource_group_name = var.dev_resource_group
#   tags                = var.common_tags
#   service_principal_id = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.2 (Optional) Subnets
# --------------------------------------------------------------------------------
# module "subnets" {
#   source = "../../modules/networking/subnets"
#   vnet_name           = module.vnet.name
#   subnets             = var.dev_subnets
#   resource_group_name = var.dev_resource_group
#   tags                = var.common_tags
#   service_principal_id = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.3 (Optional) Network Security Groups (NSGs)
# --------------------------------------------------------------------------------
# module "nsg" {
#   source = "../../modules/networking/nsg"
#   nsg_name            = var.dev_nsg_name
#   resource_group_name = var.dev_resource_group
#   location            = var.azure_location
#   security_rules      = var.dev_nsg_rules
#   tags                = var.common_tags
#   service_principal_id = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.4 (Optional) Route Tables
# --------------------------------------------------------------------------------
# module "route_table" {
#   source = "../../modules/networking/route-table"
#   route_table_name    = var.dev_route_table_name
#   resource_group_name = var.dev_resource_group
#   location            = var.azure_location
#   routes              = var.dev_route_table_routes
#   tags                = var.common_tags
#   service_principal_id = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.5 (Optional) Azure Firewall
# --------------------------------------------------------------------------------
# module "firewall" {
#   source = "../../modules/networking/firewall"
#   firewall_name       = var.dev_firewall_name
#   resource_group_name = var.dev_resource_group
#   location            = var.azure_location
#   tags                = var.common_tags
#   service_principal_id = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.6 (Optional) Private Endpoints
# --------------------------------------------------------------------------------
# module "storage_private_endpoint" {
#   source = "../../modules/networking/private-endpoint"
#   name                         = "pe-${module.poc_storage_account.name}"
#   resource_group_name          = var.dev_resource_group
#   location                     = var.azure_location
#   subnet_id                    = module.subnets.subnet_ids["private-endpoint"]
#   private_connection_resource_id = module.poc_storage_account.id
#   subresource_names            = ["file", "blob"]
#   tags                         = var.common_tags
#   service_principal_id         = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.7 (Optional) Private DNS Zones & Links
# --------------------------------------------------------------------------------
# module "private_dns_zone" {
#   source = "../../modules/networking/private-dns"
#   dns_zone_name         = var.dev_private_dns_zone_name
#   resource_group_name   = var.dev_resource_group
#   vnet_link_name        = var.dev_private_dns_vnet_link_name
#   virtual_network_id    = module.vnet.id
#   registration_enabled  = false
#   tags                  = var.common_tags
#   service_principal_id  = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 2.8 (Optional) Virtual Network Gateway
# --------------------------------------------------------------------------------
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

# --------------------------------------------------------------------------------
# 2.9 Storage Account
# --------------------------------------------------------------------------------
# NOTE: Assign RBAC roles (e.g., "Storage File Data SMB Share Contributor") at the STORAGE ACCOUNT LEVEL for all users/groups that need access to file shares. This is the Microsoft recommended best practice for Azure Files RBAC.
# Documentation: Role Assignments Created by This Module
# PRECONDITIONS FOR CREATING THE STORAGE ACCOUNT:
# 1. The resource group must already exist (see Section 1 for details).
# 2. The service principal (or user) running Terraform must have the following role assignments:
#
#    Subscription Level (typically assigned by onboarding scripts, e.g., step2_grant_permissions.sh):
#      - Reader
#      - Storage Account Contributor
#      - [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor (if using private endpoints)
#      - Private DNS Zone Contributor (if using private DNS)
#      - Monitoring Contributor (if enabling monitoring/diagnostics)
#      (Assign only those truly needed at subscription scope for least privilege.)
#
#    Resource Group Level (typically assigned by step6_create_resource_group.sh):
#      - Storage Account Contributor
#      - ag-pssg-azure-files-poc-dev-role-assignment-writer (custom role, if required)
#
# 3. The storage account name must be globally unique and conform to Azure naming rules.
# 4. Any required networking resources (e.g., VNet, subnets, NSGs) must exist if using advanced networking features.
# 5. If using private endpoints, ensure the subnet and necessary permissions are in place.
# 6. Tags, location, and other variables must be set appropriately in the environment or variable files.
# --------------------------------------------------------------------------------
# OUTPUTS:
#     This module provisions the storage account and, if enabled, assigns the following roles:
#     Storage Blob Data Contributor
#     Storage File Data SMB Share Contributor
#     Storage File Data Privileged Contributor
#     Storage Blob Data Owner
# NOTE: This module call assumes that the underlying module definition in 
# `modules/storage/account/main.tf` has been temporarily set to allow public
# network access for this pipeline run to succeed.
module "poc_storage_account" {
  source = "../../modules/storage/account"

  storage_account_name = var.dev_storage_account_name
  resource_group_name  = data.azurerm_resource_group.main.name
  location             = data.azurerm_resource_group.main.location
  tags                 = var.common_tags
  service_principal_id = var.dev_service_principal_id

  # NOTE: The storage account module should be configured to allow public access
  # for this initial deployment step, otherwise the GitHub runner will be blocked
  # by the firewall. This can be hardened in a subsequent step.
}
#================================================================================
# SECTION 2.9.1: DATA PLANE ROLE ASSIGNMENT AND DELAY
#================================================================================
# This section assigns the necessary DATA PLANE role to the service principal
# to allow it to create resources INSIDE the storage account (e.g., file shares).
# A time_sleep resource is used to pause execution, ensuring the role assignment
# has propagated through Azure's identity system before proceeding. This is the
# solution to the "race condition" where Terraform tries to create the file share
# before the required permissions are active.
#--------------------------------------------------------------------------------

resource "azurerm_role_assignment" "storage_data_contributor_for_files" {
  # This role allows creating, deleting, and managing Azure file shares.
  role_definition_name = "Storage File Data SMB Share Contributor"

  # The scope is the specific storage account we just created.
  scope = module.poc_storage_account.id

  # The principal is the Service Principal running this pipeline.
  principal_id = var.dev_service_principal_id
}

# This resource creates an explicit dependency and forces a pause.
# It waits for the role assignment above to complete, then sleeps for 45s.
resource "time_sleep" "wait_for_role_propagation" {
  create_duration = "45s"

  # This trigger ensures the sleep only starts after the role assignment is submitted.
  triggers = {
    role_assignment_id = azurerm_role_assignment.storage_data_contributor_for_files.id
  }
}

#================================================================================
# SECTION 3: DATA PLANE RESOURCES
#================================================================================
# 3.1 File Share
# 3.2 (Optional) Blob Container
# 3.3 (Optional) Storage Management Policy

# --------------------------------------------------------------------------------
# 3.1 File Share
# --------------------------------------------------------------------------------
# PRECONDITIONS FOR CREATING THE FILE SHARE:
# 1. The storage account must already exist and be accessible (see Section 2.9).
# 2. The service principal (or user) running Terraform must have the following role assignments:
#    - Storage File Data SMB Share Contributor (at the storage account level)
#      (Required for creating, deleting, and managing Azure file shares and granting SMB access.)
#    - Storage File Data SMB Share Elevated Contributor (optional, at the storage account level)
#      (Required only if you need to manage NTFS ACLs/ownership via Azure.)
#    - Any additional roles required for advanced features (e.g., Private Endpoint Contributor, if using private endpoints).
# 3. If using ACLs, Azure AD authentication must be enabled on the storage account and 'enabledOnboardedWindowsACL' set to true.
# 4. The file share name must conform to Azure naming rules and be unique within the storage account.
# 5. All required variables (e.g., storage account name, file share name, quota) must be set in the environment or variable files.
# --------------------------------------------------------------------------------
# OUTPUTS:
#     This module provisions the Azure file share and, if enabled, may assign the following roles:
#     - Storage File Data SMB Share Contributor (at the storage account level)
#     - Storage File Data SMB Share Elevated Contributor (optional, at the storage account level)
#     - (No additional roles are assigned unless explicitly configured in the module.)
#     - Outputs include the file share name, storage account name, and resource IDs for downstream modules.
# --------------------------------------------------------------------------------
# NOTE: Role, RBAC, and ACL Requirements for File Share
#
# - The service principal or user creating/managing the file share must have:
#   * Azure RBAC: "Storage File Data SMB Share Contributor" (or higher) assigned at the STORAGE ACCOUNT LEVEL (recommended by Microsoft).
#   * ACLs: If granular access is required, ensure NTFS ACLs are set on the file share after creation.
# - RBAC controls management plane (create/delete/configure) and grants mount/access rights.
# - ACLs (NTFS/Windows permissions) control data plane (read/write/list within the share).
# - Both RBAC and ACLs are required for full access:
#     - RBAC allows mounting and basic access to the share.
#     - ACLs enforce per-file and per-folder permissions (preserved if migrated with tools like robocopy/AzCopy).
# - To use ACLs, set enabledOnboardedWindowsACL = true on the file share and enable Azure AD authentication on the storage account.
# - Assign RBAC roles to Entra (Azure AD) users/groups at the storage account level and set NTFS ACLs for granular access control.
# --------------------------------------------------------------------------------
# module "poc_file_share" {
#   source = "../../modules/storage/file-share"
#
#   # This `depends_on` block is CRITICAL. It tells Terraform to not even start
#   # creating the file share until the `time_sleep` resource is finished.
#   # This solves the permissions race condition.
#   depends_on = [
#     time_sleep.wait_for_role_propagation
#   ]
#
#   # Required
#   file_share_name      = var.dev_file_share_name
#   storage_account_name = module.poc_storage_account.name
#   quota_gb             = 10
#   service_principal_id = var.dev_service_principal_id
#
#   # Optional (file share–level only)
#   enabled_protocol     = "SMB"
#   access_tier          = "Hot"
#   metadata = {
#     env             = "dev"
#     project         = "ag-pssg-azure-files-poc"
#     owner           = "ag-pssg-teams"
#     ministry_name   = "AG"
#   }
#   # acls = [...] # Only if you want to set custom ACLs
# }

# --------------------------------------------------------------------------------
# 3.2 (Optional) Blob Container
# --------------------------------------------------------------------------------
# module "poc_blob_container" {
#   source = "../../modules/storage/blob-container"
#   storage_account_name    = module.poc_storage_account.name
#   container_name          = var.dev_blob_container_name
#   container_access_type   = "private"
#   service_principal_id    = var.dev_service_principal_id
# }

# --------------------------------------------------------------------------------
# 3.3 (Optional) Storage Management Policy
# --------------------------------------------------------------------------------
# module "poc_storage_management_policy" {
#   source = "../../modules/storage/management-policy"
#   storage_account_id      = module.poc_storage_account.id
#   policy                  = var.dev_storage_management_policy
#   service_principal_id    = var.dev_service_principal_id
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
#   sync_service_name      = var.dev_file_sync_service_name
#   resource_group_name    = var.dev_resource_group
#   location               = var.azure_location
#   tags                   = var.common_tags
#   service_principal_id   = var.dev_service_principal_id
#   # Add other required arguments for sync group, cloud endpoint, etc.
# }

# --------------------------------------------------------------------------------
# 4.2 (Optional) Monitoring & Security
# --------------------------------------------------------------------------------
# module "monitoring" {
#   source = "../../modules/monitoring"
#   log_analytics_workspace_name = var.dev_log_analytics_workspace_name
#   resource_group_name          = var.dev_resource_group
#   location                    = var.azure_location
#   tags                        = var.common_tags
#   service_principal_id         = var.dev_service_principal_id
#   # Add other required arguments for diagnostics, alerts, etc.
# }

# --------------------------------------------------------------------------------
# 4.3 (Optional) Automation, Power BI, Custom Dashboards
# --------------------------------------------------------------------------------
# module "automation" {
#   source = "../../modules/automation"
#   automation_account_name = var.dev_automation_account_name
#   resource_group_name     = var.dev_resource_group
#   location                = var.azure_location
#   tags                    = var.common_tags
#   service_principal_id    = var.dev_service_principal_id
#   # Add other required arguments for runbooks, etc.
# }