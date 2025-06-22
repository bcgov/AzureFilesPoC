/*
 * =================================================================================================
 *   Azure Files PoC - CI/CD and Terraform Validation Script
 * =================================================================================================
 *
 * PURPOSE:
 * The primary purpose of this Terraform configuration is to serve as a comprehensive validation test
 * for the integration between GitHub Actions and Microsoft Azure. It confirms that the CI/CD
 * pipeline is correctly configured to deploy Infrastructure as Code (IaC) securely and
 * incrementally.
 *
 * -------------------------------------------------------------------------------------------------
 *
 * AZURE RESOURCES CREATED/REFERENCED BY THIS SCRIPT:
 * The following resources will be managed in your Azure subscription when this script is applied.
 *
 * | Action      | Azure Resource Type          | Terraform Resource Name                 | Azure Resource Name (Pattern)                     |
 * |-------------|------------------------------|-----------------------------------------|---------------------------------------------------|
 * | **Lookup**  | Resource Group               | data.azurerm_resource_group.validation  | `rg-<project-code>-<env>`                         |
 * | **Create**  | Network Security Group       | azurerm_network_security_group.validation | `nsg-<project-code>-<env>-01`                     |
 * | **Create**  | Subnet                       | azapi_resource.storage_pe_subnet        | `snet-<project-code>-<env>-<function>`            |
 * | **Create**  | Storage Account              | azurerm_storage_account.validation      | `st<projectcode><env>01` (globally unique)        |
 * | **Create**  | Private Endpoint             | azurerm_private_endpoint.storage_pe     | `pe-<storage-account-name>`                       |
 *
 */

# Configure the Azure and AzAPI providers, and set the required Terraform version.
terraform {
  required_version = "~> 1.0" # FIX: Added required_version to satisfy tflint.

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

# --- Variable Definitions ---
# FIX: Removed all unused variable declarations to satisfy tflint.
# Only variables that are actively used in this validation script are declared.
variable "environment" {
  description = "The target environment, e.g., 'dev'."
  type        = string
}

variable "dev_resource_group" {
  description = "The name of the pre-existing resource group to use for validation."
  type        = string
}

variable "dev_vnet_name" {
  description = "The name of the pre-existing VNet to add a subnet to."
  type        = string
}

variable "dev_vnet_resource_group" {
  description = "The name of the resource group where the pre-existing VNet is located."
  type        = string
}

variable "dev_subnet_name" {
  description = "The name for the new subnet to be created."
  type        = string
}

variable "dev_subnet_address_prefixes" {
  description = "A list of CIDR blocks for the new subnet."
  type        = list(string)
}

variable "dev_storage_account_name" {
  description = "The globally unique name for the validation storage account."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}


# Local variables
locals {
  project_prefix    = "ag-pssg-azure-poc"
  env               = var.environment
  rg_name           = var.dev_resource_group
  st_name           = var.dev_storage_account_name
  nsg_name          = "nsg-${local.project_prefix}-${local.env}-01"
  dev_subnet_name   = var.dev_subnet_name
  dev_subnet_prefix = var.dev_subnet_address_prefixes
}

# Look up the existing resource group instead of creating a new one.
data "azurerm_resource_group" "validation" {
  name = local.rg_name
}

# Network Security Group (NSG) for validation subnet.
# This will be created inside the existing resource group.
resource "azurerm_network_security_group" "validation" {
  name                = local.nsg_name
  location            = data.azurerm_resource_group.validation.location
  resource_group_name = data.azurerm_resource_group.validation.name
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

# Create the Storage Account.
resource "azurerm_storage_account" "validation" {
  name                          = local.st_name
  resource_group_name           = data.azurerm_resource_group.validation.name
  location                      = data.azurerm_resource_group.validation.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  large_file_share_enabled      = true
  access_tier                   = "Hot"
  tags                          = var.common_tags
  public_network_access_enabled = false
}

# Create the Private Endpoint.
resource "azurerm_private_endpoint" "storage_pe" {
  name                = "pe-${local.st_name}"
  location            = data.azurerm_resource_group.validation.location
  resource_group_name = data.azurerm_resource_group.validation.name
  subnet_id           = jsondecode(azapi_resource.storage_pe_subnet.output).id

  private_service_connection {
    name                           = "psc-${local.st_name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.validation.id
    subresource_names              = ["blob", "file"]
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

# --- Outputs for all resources ---
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = data.azurerm_resource_group.validation.name
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