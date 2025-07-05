# terraform/modules/storage/account/main.tf
#
# =====================================================================================
# VERIFIED WORKING WITH CI/CD (as of July 5, 2025)
# =====================================================================================
#
# The following infrastructure components have been successfully deployed via both:
#   - Local `terraform apply` on the self-hosted runner
#   - GitHub Actions workflow (CI/CD pipeline)
#
# ✅ Network Security Group (NSG) for storage subnet
# ✅ Storage Account (policy-compliant, private-only)
# ✅ Private Endpoint for Storage Account (file subresource)
# ✅ Data plane role assignment (Storage File Data SMB Share Contributor) for service principal
# ✅ Role propagation wait (time_sleep) for reliable file share automation
#
# Key policy compliance settings:
#   - `public_network_access_enabled = false` (required)
#   - No `network_rules` block present (required)
#   - (For future blob use: `allow_blob_public_access = false` should be set, but not required for Azure Files only)
#
# Outputs and Azure Portal confirm all resources are provisioned as expected.
#
# If you add new modules/resources, update this block after successful CI/CD deployment.
# =====================================================================================

terraform {
  required_version = ">= 1.6.6"
  required_providers {
    # --- CHANGE: Pin to a specific, known-stable version ---
    # This version has a different implementation for storage account creation
    # that is more likely to be compliant with strict policies.
    azurerm = { source = "hashicorp/azurerm", version = "= 3.75.0" }
    
    azapi   = { source = "azure/azapi", version = "~> 1.0" }
    time    = { source = "hashicorp/time", version = ">= 0.9.1" }
  }
  backend "azurerm" { key = "dev.terraform.tfstate" }
}

provider "azurerm" {
  features {}
  
  # --- ADD THIS LINE ---
  # This tells Terraform not to automatically register Azure Resource Providers.
  # This is required in permission-restricted environments where the
  # service principal does not have subscription-level rights to do so.
  skip_provider_registration = true
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

# This module now ONLY creates the private storage account. Its internal code has
# been cleaned up to be policy-compliant.
module "poc_storage_account" {
  source               = "../../modules/storage/account"
  storage_account_name = var.storage_account_name
  resource_group_name  = data.azurerm_resource_group.main.name
  azure_location       = var.azure_location
  tags                 = var.common_tags
  depends_on           = [module.storage_nsg]
}

# This module creates the private endpoint and connects it to the storage account.
# It will now succeed because the storage account creation is no longer blocked by policy.
# note:  Private Endpoints Required: Access to most Azure PaaS services 
# (like Storage Accounts, Key Vault, SQL Databases, etc.) is restricted to 
# private endpoints only. This means that these services will not have 
# public IP addresses and will only be accessible from within your virtual 
# network (or peered networks). Creating a PaaS service without configuring 
# a private endpoint, or attempting to enable public access after creation, 
#will be blocked by a "Deny" policy
module "storage_private_endpoint" {
  source                          = "../../modules/networking/private-endpoint"
  private_endpoint_name           = "pe-${var.storage_account_name}"
  location                        = var.azure_location
  resource_group                  = data.azurerm_resource_group.main.name
  private_endpoint_subnet_id      = module.storage_nsg.storage_subnet_id
  private_service_connection_name = "conn-to-${var.storage_account_name}"
  private_connection_resource_id  = module.poc_storage_account.id
  subresource_names               = ["file"]
  common_tags                     = var.common_tags
  service_principal_id            = var.service_principal_id
  depends_on                      = [module.poc_storage_account]
}

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
  depends_on           = [module.poc_storage_account]
}

resource "time_sleep" "wait_for_role_propagation" {
  create_duration = "45s"
  triggers        = { role_assignment_id = azurerm_role_assignment.storage_data_contributor_for_files.id }
  depends_on      = [azurerm_role_assignment.storage_data_contributor_for_files]
}

resource "azurerm_role_assignment" "storage_data_contributor_for_blobs" {
  role_definition_name = "Storage Blob Data Contributor"
  scope                = module.poc_storage_account.id
  principal_id         = var.service_principal_id
  depends_on           = [module.poc_storage_account]
}

resource "time_sleep" "wait_for_blob_role_propagation" {
  create_duration = "120s" # Increased from 45s to allow for Azure permission propagation
  triggers        = { role_assignment_id = azurerm_role_assignment.storage_data_contributor_for_blobs.id }
  depends_on      = [azurerm_role_assignment.storage_data_contributor_for_blobs]
}

resource "azurerm_role_assignment" "storage_account_contributor" {
  role_definition_name = "Storage Account Contributor"
  scope                = module.poc_storage_account.id
  principal_id         = var.service_principal_id
  depends_on           = [module.poc_storage_account]
}

resource "time_sleep" "wait_for_storage_account_role" {
  create_duration = "180s"
  triggers        = { role_assignment_id = azurerm_role_assignment.storage_account_contributor.id }
  depends_on      = [azurerm_role_assignment.storage_account_contributor]
}

#================================================================================
# SECTION 3: DATA PLANE RESOURCES (DISABLED FOR TEST)
#================================================================================
module "poc_file_share" {
  source     = "../../modules/storage/file-share"
  depends_on = [time_sleep.wait_for_role_propagation]

  file_share_name       = var.file_share_name
  storage_account_name  = module.poc_storage_account.name
  storage_account_id    = module.poc_storage_account.id
  quota_gb              = 10
  service_principal_id  = var.service_principal_id
  enabled_protocol      = "SMB"
  access_tier           = "Hot"
  metadata              = {
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
module "poc_blob_container" {
  source = "../../modules/storage/blob-container"
  depends_on = [
    time_sleep.wait_for_blob_role_propagation,
    time_sleep.wait_for_storage_account_role,
    azurerm_role_assignment.storage_data_contributor_for_blobs,
    azurerm_role_assignment.storage_account_contributor
  ]

  storage_account_name    = module.poc_storage_account.name
  storage_account_id      = module.poc_storage_account.id  # Add this line
  container_name          = var.blob_container_name
  container_access_type   = "private"
  metadata                = {
    env            = "dev"
    project        = var.common_tags["project"]
    owner          = var.common_tags["owner"]
    account_coding = var.common_tags["account_coding"]
    billing_group  = var.common_tags["billing_group"]
    ministry_name  = var.common_tags["ministry_name"]
  }
}


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