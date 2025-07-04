# --- terraform/environments/dev/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'dev' environment for Azure Files PoC.
#
# UPDATED: Applied lessons learned from cicd/main.tf for BC Gov policy compliance
# 
# KEY CHANGES APPLIED:
# 1. Added AzAPI provider for policy-compliant subnet creation
# 2. Created storage/nsg module that combines NSG and subnet creation
# 3. Uses data sources to reference existing VNet instead of creating new one
# 4. Added proper dependency management to prevent "AnotherOperationInProgress" errors
# 5. Updated bastion configuration to use the same pattern as cicd environment
# 6. Consistent variable naming aligned with working cicd pattern
#
# PATTERN: NSG → Subnet+NSG (via AzAPI) → Resources that use the subnet
# This ensures BC Gov policy compliance and prevents Azure API conflicts.

terraform {
  required_version = ">= 1.6.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
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

provider "azapi" {
  # AzAPI provider for BC Gov policy-compliant resources
  # Used for creating subnets with NSG association in a single operation
}

# ================================================================================
# Azure Infrastructure as Code (IaC) Best Practices for BC Gov Policy Compliance
# -------------------------------------------------------------------------------
# UPDATED APPROACH: Policy-Compliant Networking with AzAPI
# -------------------------------------------------------------------------------
# This version uses the lessons learned from the CICD environment to implement
# BC Gov Azure Policy compliant networking using AzAPI for subnet creation.
# 
# KEY CHANGES FROM ORIGINAL VERSION:
# 1. Added AzAPI provider for policy-compliant subnet creation
# 2. NSG and subnet creation combined in single modules (modules/storage/nsg)
# 3. Proper dependency management to avoid "AnotherOperationInProgress" errors
# 4. Reference existing VNet instead of creating new one
# 5. Consistent variable naming aligned with working CICD pattern
# -------------------------------------------------------------------------------
# RESOURCE CREATION SEQUENCING (UPDATED)
# -------------------------------------------------------------------------------
# 1. Resource Group (pre-existing, referenced via data source)
# 2. Core Infrastructure:
#    - 2.1 NSG + Subnet Creation (combined, using AzAPI for policy compliance)
#    - 2.2 Private Endpoints (optional, after subnet creation)
#    - 2.3 Private DNS Zones (optional, after private endpoints)
#    - 2.4 Storage Account (after networking if using private endpoints)
# 3. Data Plane Resources:
#    - 3.1 File Share (after storage account + role assignment delay)
#    - 3.2 Blob Container (optional, after storage account)
#    - 3.3 Management Policy (optional, after storage account)
# 4. Monitoring, Automation, File Sync (optional, after core resources)
# -------------------------------------------------------------------------------
# BC Gov Policy Compliance:
# - Subnets MUST have NSG association at creation time
# - Use AzAPI to create subnet with NSG in single operation
# - Proper sequencing prevents Azure API "AnotherOperationInProgress" errors
# - Reference existing VNet from central landing zone
# ===============================================================================

#================================================================================
# DEPLOYMENT SUMMARY - CURRENT STATE
#================================================================================
# Resources that will be created when this script is executed:
# 1. Resource Group (pre-existing, referenced via data source)
# 2. VNet Reference (pre-existing, referenced via data source)
# 3. Storage NSG + Subnet (policy-compliant creation using AzAPI)
# 4. Storage Account (enabled - confirmed working)
# 5. Role Assignment + Delay (for service principal data plane access)
# 6. File Share (commented out - enable after storage account is working)
# 
# Optional resources (commented out):
# - Private Endpoints (for secure access to storage)
# - Private DNS Zones (for name resolution)
# - Blob Container (for blob storage)
# - Management Policy (for lifecycle management)
# - Monitoring, Automation, File Sync
#================================================================================

#================================================================================
# SECTION 1: CORE RESOURCE GROUP
#================================================================================
# Resource groups are pre-created by the BC Gov landing zone/central IT. 
# Service principals and Terraform are NOT authorized to create resource groups.
# Reference the pre-created resource group by name (var.resource_group) in all modules.
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
#   - <project-name>-dev-role-assignment-writer (custom role)
#
# These assignments are required for the service principal to deploy and manage
# resources in this environment. See onboarding scripts for details.
# --------------------------------------------------------------------------------
#ASSUMPTION:  This terraform script assumes the resource group exists
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ===============================================================================
# SECTION 1.1: EXISTING VNET REFERENCE
# ===============================================================================
# Reference the existing VNet that was created by the central team
# This VNet is used for hosting the development environment resources
# -------------------------------------------------------------------------------
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

#================================================================================
# SECTION 2: CORE INFRASTRUCTURE (NETWORKING & STORAGE)
#================================================================================
# 2.1 Network Security Groups (NSGs) and Subnets
# 2.2 Private Endpoints (Optional)
# 2.3 Private DNS Zones & Links (Optional)
# 2.4 Storage Account

# ===============================================================================
# SECTION 2.1: NETWORK SECURITY GROUPS (NSG) AND SUBNETS
# -------------------------------------------------------------------------------
# BC Gov Policy Requirement: Subnets must have NSG association at creation time
# Solution: Use AzAPI to create subnet with NSG association in single operation
# 
# Pattern: NSG → Subnet+NSG (via AzAPI) → Resources that use the subnet
# This prevents the "AnotherOperationInProgress" error and ensures policy compliance
# -------------------------------------------------------------------------------

# 2.1.1 Storage Subnet NSG - Creates both NSG and subnet with association
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

# ===============================================================================
# SECTION 2.2: PRIVATE ENDPOINTS (OPTIONAL)
# -------------------------------------------------------------------------------
# Private endpoints connect Azure services to the VNet privately
# This allows secure access to storage accounts without exposing them to the internet
# -------------------------------------------------------------------------------
# module "storage_private_endpoint" {
#   source = "../../modules/networking/private-endpoint"
#   name                         = "pe-${module.poc_storage_account.name}"
#   resource_group_name          = data.azurerm_resource_group.main.name
#   location                     = var.azure_location
#   subnet_id                    = module.storage_nsg.storage_subnet_id
#   private_connection_resource_id = module.poc_storage_account.id
#   subresource_names            = ["file", "blob"]
#   tags                         = var.common_tags
#   service_principal_id         = var.service_principal_id
# }

# ===============================================================================
# SECTION 2.3: PRIVATE DNS ZONES & LINKS (OPTIONAL)
# -------------------------------------------------------------------------------
# Private DNS zones provide name resolution for private endpoints
# -------------------------------------------------------------------------------
# module "private_dns_zone" {
#   source = "../../modules/networking/private-dns"
#   dns_zone_name         = var.private_dns_zone_name
#   resource_group_name   = data.azurerm_resource_group.main.name
#   vnet_link_name        = var.private_dns_vnet_link_name
#   virtual_network_id    = data.azurerm_virtual_network.spoke_vnet.id
#   registration_enabled  = false
#   tags                  = var.common_tags
#   service_principal_id  = var.service_principal_id
# }

# ===============================================================================
# SECTION 2.4: STORAGE ACCOUNT
# -------------------------------------------------------------------------------
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
#      - <project-name>-dev-role-assignment-writer (custom role, if required)
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

  storage_account_name = var.storage_account_name
  resource_group_name  = data.azurerm_resource_group.main.name
  location             = data.azurerm_resource_group.main.location
  tags                 = var.common_tags
  service_principal_id = var.service_principal_id

  # NOTE: The storage account module should be configured to allow public access
  # for this initial deployment step, otherwise the GitHub runner will be blocked
  # by the firewall. This can be hardened in a subsequent step.
}
#================================================================================
# SECTION 2.4.1: DATA PLANE ROLE ASSIGNMENT AND DELAY
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
  principal_id = var.service_principal_id
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
#   file_share_name      = var.file_share_name
#   storage_account_name = module.poc_storage_account.name
#   quota_gb             = 10
#   service_principal_id = var.service_principal_id
#
#   # Optional (file share–level only)
#   enabled_protocol     = "SMB"
#   access_tier          = "Hot"
#   metadata = {
#     env             = "dev"
#     project         = "<project-name>"
#     owner           = "<project-owner>"
#     ministry_name   = "<ministry-code>"
#   }
#   # acls = [...] # Only if you want to set custom ACLs
# }

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

# ===============================================================================
# SECTION 4.4: BASTION HOST (OPTIONAL)
# -------------------------------------------------------------------------------
# Bastion provides secure RDP/SSH access to VMs without exposing them to the internet
# Uses the same policy-compliant NSG+subnet pattern as storage
# -------------------------------------------------------------------------------
# module "bastion_nsg" {
#   source                = "../../modules/bastion/nsg"
#   resource_group_name   = data.azurerm_resource_group.main.name
#   location              = var.azure_location
#   nsg_name              = var.bastion_network_security_group
#   tags                  = var.common_tags
#   vnet_id               = data.azurerm_virtual_network.spoke_vnet.id
#   address_prefix        = var.bastion_address_prefix[0]
#   subnet_name           = var.bastion_subnet_name
#   
#   # Dependency: Wait for storage subnet to be created first
#   depends_on = [module.storage_nsg]
# }

# module "bastion" {
#   source                = "../../modules/bastion"
#   resource_group_name   = data.azurerm_resource_group.main.name
#   location              = data.azurerm_resource_group.main.location
#   vnet_name             = data.azurerm_virtual_network.spoke_vnet.name
#   vnet_resource_group   = data.azurerm_virtual_network.spoke_vnet.resource_group_name
#   bastion_name          = var.bastion_name
#   public_ip_name        = var.bastion_public_ip_name
#   subnet_id             = module.bastion_nsg.bastion_subnet_id
# }