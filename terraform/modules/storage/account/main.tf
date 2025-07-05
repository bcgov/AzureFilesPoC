# terraform/modules/storage/account/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# This module creates the most minimal, private-only Azure Storage Account possible
# to ensure compliance with strict Azure Policies that block public endpoints.
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.azure_location
  tags                     = var.tags

  # --- Required Arguments for a Standard Account ---
  account_tier             = "Standard"
  account_replication_type = "LRS" # Local-redundant storage

  # --- CRITICAL SETTINGS for BC Gov Policy Compliance ---
  # This explicitly disables the public network endpoint
  public_network_access_enabled = false
  
  # THIS IS THE MISSING SETTING - Required by BC Gov policy
  # The policy error specifically checks for allowBlobPublicAccess = false
  allow_nested_items_to_be_public = false
  
  # NOTE: All other optional arguments like 'large_file_share_enabled',
  # 'network_rules', etc., have been removed to prevent the provider from
  # sending any conflicting or unnecessary properties to the Azure API.
}