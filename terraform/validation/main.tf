/*
 * Azure Files PoC - Terraform Validation Configuration
 * Purpose: Minimal Terraform configuration to validate CI/CD integration
 */

# Configure the Azure and AzAPI providers
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# --- All your variable definitions are correct ---
variable "dev_location" { type = string }
variable "environment" { type = string }
variable "dev_resource_group" { type = string }
variable "common_tags" { type = map(string) }
variable "dev_vnet_name" { type = string }
variable "dev_subnet_name" { type = string }
variable "dev_subnet_address_prefixes" { type = list(string) }
variable "dev_vnet_resource_group" { type = string }
variable "dev_subscription_name" { type = string }
variable "dev_subscription_id" { type = string }
variable "dev_storage_account_name" { type = string }
variable "dev_file_share_name" { type = string }
variable "dev_file_share_quota_gb" { type = number }
variable "dev_vnet_id" { type = string }
variable "dev_vnet_address_space" { type = list(string) }
variable "dev_dns_servers" { type = list(string) }

# Local variables
locals {
  project_prefix = "ag-pssg-azure-poc"
  env            = var.environment
  rg_name        = "rg-${local.project_prefix}-${local.env}"
  st_name        = var.dev_storage_account_name
  sc_name        = "sc-${local.project_prefix}-${local.env}-01"
  validation_tags = {
    Project     = "Azure Files PoC"
    Environment = var.environment
    Purpose     = "Validation"
    Terraform   = "true"
  }
  dev_subnet_name   = var.dev_subnet_name
  dev_subnet_prefix = var.dev_subnet_address_prefixes
  nsg_name          = "nsg-${local.project_prefix}-${local.env}-01"
}

# Resource group for validation
resource "azurerm_resource_group" "validation" {
  name     = local.rg_name
  location = var.dev_location
  tags     = var.common_tags
}

# Network Security Group (NSG) for validation subnet
resource "azurerm_network_security_group" "validation" {
  name                = local.nsg_name
  location            = var.dev_location
  resource_group_name = azurerm_resource_group.validation.name
  tags                = var.common_tags
}

# Reference the existing VNet
data "azurerm_virtual_network" "existing" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

# Create subnet using AzAPI with NSG association
resource "azapi_resource" "storage_pe_subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = local.dev_subnet_name
  parent_id = data.azurerm_virtual_network.existing.id
  body = jsonencode({
    properties = {
      addressPrefix                     = local.dev_subnet_prefix[0]
      networkSecurityGroup              = { id = azurerm_network_security_group.validation.id }
      privateEndpointNetworkPolicies    = "Disabled"
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  })
  response_export_values = ["id"]
}

# --- FIX: THIS ENTIRE BLOCK IS NOW UNCOMMENTED ---
# Storage account for validation
resource "azurerm_storage_account" "validation" {
  name                     = local.st_name
  resource_group_name      = azurerm_resource_group.validation.name
  location                 = var.dev_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true
  access_tier              = "Hot"
  tags                     = var.common_tags
  public_network_access_enabled = false
}

# --- FIX: THIS ENTIRE BLOCK IS NOW UNCOMMENTED ---
# Private endpoint for storage (blob and file)
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-${local.st_name}"
  location            = var.dev_location
  resource_group_name = azurerm_resource_group.validation.name
  subnet_id           = jsondecode(azapi_resource.storage_pe_subnet.output).id

  private_service_connection {
    name                           = "psc-${local.st_name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.validation.id
    subresource_names              = ["blob", "file"]
  }

  lifecycle {
    ignore_changes = [ private_dns_zone_group ]
  }
}

# --- All your outputs will now work correctly ---
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = jsondecode(azapi_resource.storage_pe_subnet.output).id
}

output "storage_account_name" {
  description = "The name of the created storage account"
  value       = azurerm_storage_account.validation.name
}

output "storage_account_id" {
  description = "The ID of the created storage account"
  value       = azurerm_storage_account.validation.id
}

output "storage_account_resource_group" {
  description = "The resource group of the storage account"
  value       = azurerm_storage_account.validation.resource_group_name
}

output "storage_account_location" {
  description = "The location of the storage account"
  value       = azurerm_storage_account.validation.location
}