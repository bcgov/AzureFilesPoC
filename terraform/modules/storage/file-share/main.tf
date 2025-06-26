terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75" # Version for cross_tenant_replication_enabled
    }
  }
}

provider "azurerm" {
  features {}
}

# Data source to get a reference to the existing resource group
data "azurerm_resource_group" "main" {
  name = var.dev_resource_group
}

# Defines the Storage Account resource based on your JSON export
resource "azurerm_storage_account" "main" {
  # --- Core Identification ---
  name                = var.dev_storage_account_name
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location
  tags                = var.common_tags

  # --- SKU and Kind ---
  # Corresponds to sku.name = "Standard_LRS" and kind = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # --- Security and Access ---
  # Corresponds to properties.supportsHttpsTrafficOnly = true
  https_traffic_only_enabled = true
  # Corresponds to properties.minimumTlsVersion = "TLS1_2"
  min_tls_version = "TLS1_2"
  # Corresponds to properties.allowBlobPublicAccess = false
  allow_blob_public_access = false
  # Corresponds to properties.allowSharedKeyAccess = true
  shared_access_key_enabled = true
  # Corresponds to properties.defaultToOAuthAuthentication = false
  default_to_oauth_authentication = false
  # Corresponds to properties.isLocalUserEnabled = true
  local_user_enabled = true
  # Corresponds to properties.allowCrossTenantReplication = true
  cross_tenant_replication_enabled = true

  # --- Features ---
  # Corresponds to properties.largeFileSharesState = "Enabled"
  large_file_share_enabled = true
  # Corresponds to properties.isHnsEnabled = false (for Data Lake Gen2)
  is_hns_enabled = false

  # --- Network Rules ---
  # This is the primary setting from properties.publicNetworkAccess = "Disabled"
  public_network_access_enabled = false

  # The network_rules block is still good practice to define, even with public access disabled.
  # This reflects properties.networkAcls
  network_rules {
    default_action             = "Deny" # Best practice when public access is disabled
    bypass                     = ["AzureServices"]
    ip_rules                   = [] # Corresponds to empty ipRules array
    virtual_network_subnet_ids = [] # Corresponds to empty virtualNetworkRules array
  }
}