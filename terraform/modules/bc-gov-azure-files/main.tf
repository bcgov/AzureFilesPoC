# BC Government Azure Files Module

/*
 * BC Gov Policy Note:
 * All storage accounts and other PaaS resources created by this module must have public network access disabled
 * (public_network_access_enabled = false) to ensure compliance with BC Gov security requirements.
 * Access must be restricted to private endpoints or approved network rules only.
 */

# Required providers configuration will be handled at the root level
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.0"
    }
  }
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
  account_kind            = "StorageV2"
  
  enable_https_traffic_only = true
  tags = var.common_tags

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags that might be managed by BC Gov policies
      tags["CreatedBy"],
      tags["CreatedOn"]
    ]
  }
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
  tags               = var.common_tags
}

# Using AzAPI for subnet creation to comply with BC Gov policy requiring NSG
resource "azapi_resource" "client_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = var.subnet_name
  parent_id = azurerm_virtual_network.poc_vnet.id

  body = jsonencode({
    properties = {
      addressPrefix = var.subnet_address_prefixes[0]
      serviceEndpoints = [
        {
          service = "Microsoft.Storage"
        }
      ]
      networkSecurityGroup = {
        id = azurerm_network_security_group.client_subnet_nsg.id
      }
    }
  })
}

# NSG for the client subnet
resource "azurerm_network_security_group" "client_subnet_nsg" {
  name                = "nsg-${var.subnet_name}"
  location            = azurerm_resource_group.poc_rg.location
  resource_group_name = azurerm_resource_group.poc_rg.name
  tags                = var.common_tags
}

# Configure network rules for the storage account
resource "azurerm_storage_account_network_rules" "storage_rules" {
  storage_account_id = azurerm_storage_account.files_storage.id
  default_action     = "Deny"
  virtual_network_subnet_ids = [
    azapi_resource.client_subnet.id
  ]
  bypass = ["AzureServices"]
}
