# Azure Files PoC - Main Terraform Configuration
# BC Government - Azure Landing Zone Deployment

# Configure the Azure provider
# ❗ CRITICAL RULE: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW ❗
# This file describes resources but does not create them until terraform apply is manually executed
# Always complete the DEPLOYMENT_CHECKLIST.md before applying this configuration

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  # Uncomment this if you want to use Terraform Cloud or Azure Storage for state management
  # backend "azurerm" {
  #   # State file configuration would go here
  # }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  # No credentials here - use environment variables or az login
}

# Resource group for the Azure Files PoC
resource "azurerm_resource_group" "poc_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# Storage account for Azure Files
resource "azurerm_storage_account" "files_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.poc_rg.name
  location                 = azurerm_resource_group.poc_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  
  # Enable https traffic only
  enable_https_traffic_only = true
  
  # Advanced threat protection
  tags = var.common_tags
}

# Create Azure File Share
resource "azurerm_storage_share" "file_share" {
  name                 = var.file_share_name
  storage_account_name = azurerm_storage_account.files_storage.name
  quota                = var.file_share_quota_gb
}

# Virtual Network for the PoC
resource "azurerm_virtual_network" "poc_vnet" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
  tags                = var.common_tags
}

# Subnet for the file share clients
resource "azurerm_subnet" "client_subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.poc_rg.name
  virtual_network_name = azurerm_virtual_network.poc_vnet.name
  address_prefixes     = var.subnet_address_prefixes
  
  # Enable service endpoints for Azure Storage
  service_endpoints    = ["Microsoft.Storage"]
}

# Configure network rules for the storage account
resource "azurerm_storage_account_network_rules" "storage_rules" {
  storage_account_id = azurerm_storage_account.files_storage.id
  default_action     = "Deny"
  virtual_network_subnet_ids = [
    azurerm_subnet.client_subnet.id
  ]
  bypass = ["AzureServices"]
}

# Output the storage account name and file share details
output "storage_account_name" {
  value = azurerm_storage_account.files_storage.name
}

output "file_share_name" {
  value = azurerm_storage_share.file_share.name
}

output "file_share_url" {
  value = azurerm_storage_account.files_storage.primary_file_endpoint
}

# Storage account access keys should NOT be output in production
# This is for demonstration purposes only
output "access_keys" {
  value     = azurerm_storage_account.files_storage.primary_access_key
  sensitive = true
}
