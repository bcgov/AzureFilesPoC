/*
 * Azure Files PoC - Terraform Validation Configuration
 * Purpose: Minimal Terraform configuration to validate CI/CD integration
 *
 * Validation/Test Checklist:
 * | Resource/Step                | Status   | Notes                        |
 * |------------------------------|----------|------------------------------|
 * | Resource Group                | ✅       | Tested and validated         |
 * | Network Security Group (NSG)  | ✅       | Tested and validated         |
 * | Subnet (with NSG association) | ✅       | Tested and validated         |
 * | Storage Account               | ⬜       | Tested and validated         |
 * | Private Endpoint              | ⬜       | Tested and validated         |
 * | Blob Container                | ⬜       | Not yet tested               |
 * | Test Blob file                | ⬜       | Not yet tested               |
 *
 * Dependencies:
 *   - Authenticate with Azure using 'az login' (no client secret needed for OIDC/GitHub Actions)
 *   - Variable values are sourced from terraform.tfvars, populated from .env/azure_full_inventory.json
 *   - If using service principal authentication, values can be provided in secrets.tfvars
 *   - Requires AzAPI provider for subnet creation with NSG association due to Azure Policy
 *
 * Note: Do NOT create the VNet or resource group if they exist. Use data sources and variables from .env/azure_full_inventory.json.
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

# --- Variables (No changes needed here) ---
variable "dev_location" {
  description = "The Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment (dev, test, prod)"
  type        = string
}

variable "dev_resource_group" {
  description = "The name of the resource group to use"
  type        = string
  validation {
    condition     = length(var.dev_resource_group) > 0
    error_message = "Resource group name must not be empty."
  }
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

variable "dev_vnet_name" {
  description = "The name of the existing virtual network"
  type        = string
  validation {
    condition     = length(var.dev_vnet_name) > 0
    error_message = "VNet name must not be empty."
  }
}

variable "dev_subnet_name" {
  description = "The name of the subnet to create in the existing VNet"
  type        = string
  default     = ""
}

variable "dev_subnet_address_prefixes" {
  description = "The address prefixes for the subnet"
  type        = list(string)
  default     = []
}

variable "dev_vnet_resource_group" {
  description = "The resource group of the VNet"
  type        = string
  validation {
    condition     = length(var.dev_vnet_resource_group) > 0
    error_message = "VNet resource group name must not be empty."
  }
}

variable "dev_subscription_name" {
  description = "The name of the Azure subscription"
  type        = string
}

variable "dev_subscription_id" {
  description = "The ID of the Azure subscription"
  type        = string
}

variable "dev_storage_account_name" {
  description = "The name of the storage account for validation"
  type        = string
}

variable "dev_file_share_name" {
  description = "The name of the Azure File Share for validation"
  type        = string
}

variable "dev_file_share_quota_gb" {
  description = "Quota for the Azure File Share in GB"
  type        = number
}

variable "dev_vnet_id" {
  description = "The full Azure resource ID of the VNet"
  type        = string
}

variable "dev_vnet_address_space" {
  description = "The address space of the VNet"
  type        = list(string)
}

variable "dev_dns_servers" {
  description = "DNS servers for the VNet"
  type        = list(string)
}

# Local variables
locals {
  project_prefix = "ag-pssg-azure-poc"
  env            = var.environment
  rg_name        = "rg-${local.project_prefix}-${local.env}"
  st_name        = lower(replace("st${local.project_prefix}${local.env}01", "-", ""))
  sc_name        = "sc-${local.project_prefix}-${local.env}-01"
  validation_tags = {
    Project     = "Azure Files PoC"
    Environment = var.environment
    Purpose     = "Validation"
    Terraform   = "true"
  }
  dev_subnet_name   = "snet-${local.project_prefix}-${local.env}-storage-pe"
  dev_subnet_prefix = ["10.46.73.128/28"]
  nsg_name          = "nsg-${local.project_prefix}-${local.env}-01"
}

# Resource group for validation
resource "azurerm_resource_group" "validation" {
  name     = local.rg_name
  location = var.dev_location
  tags     = local.validation_tags

  lifecycle {
    prevent_destroy = false
  }
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
  # locks is not a valid argument for azapi_resource, this line can be removed or commented out
  # locks     = [data.azurerm_virtual_network.existing.id]

  body = jsonencode({
    properties = {
      addressPrefix = local.dev_subnet_prefix[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.validation.id
      }
      # <-- FIX 1: This MUST be "Disabled" for a Private Endpoint to be deployed into the subnet.
      privateEndpointNetworkPolicies = "Disabled"
      # <-- FIX 2: It's best practice to also disable this for a dedicated PE subnet.
      privateLinkServiceNetworkPolicies = "Disabled"
    }
  })

  response_export_values = ["*"]
}


# Storage account for validation
# resource "azurerm_storage_account" "validation" {
#   name                     = local.st_name
#   resource_group_name      = local.rg_name
#   location                 = var.dev_location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   large_file_share_enabled = true
#   access_tier              = "Hot"
#   tags = merge(
#     local.validation_tags,
#     {
#       account_coding = var.common_tags["account_coding"]
#       billing_group  = var.common_tags["billing_group"]
#       ministry_name  = var.common_tags["ministry_name"]
#     }
#   )
#   public_network_access_enabled = false
#
#   # <-- FIX 5: The `network_rules` block is invalid when public access is disabled. It has been removed.
# }

# Private endpoint for storage (blob and file)
# resource "azurerm_private_endpoint" "storage_pe" {
#   name                = "pe-${local.st_name}"
#   location            = var.dev_location
#   resource_group_name = local.rg_name
#   subnet_id           = jsondecode(azapi_resource.storage_pe_subnet.output).id
#
#   private_service_connection {
#     name                           = "psc-${local.st_name}"
#     private_connection_resource_id = azurerm_storage_account.validation.id
#     subresource_names              = ["blob", "file"]
#     is_manual_connection           = false
#   }
#
#   # If Azure Policy manages the Private DNS Zone, ignore changes to DNS zone group
#   lifecycle {
#     ignore_changes = [
#       private_dns_zone_group
#     ]
#   }
# }


# Outputs for debugging and integration
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = jsondecode(azapi_resource.storage_pe_subnet.output).id
}

output "debug_subnet_name" {
  description = "The name of the created subnet"
  value       = local.dev_subnet_name
}

output "debug_subnet_resource_group_name" {
  description = "The resource group name of the subnet"
  value       = var.dev_vnet_resource_group # This is correct as it's the RG of the existing VNet
}

output "debug_subnet_virtual_network_name" {
  description = "The virtual network name of the subnet"
  value       = var.dev_vnet_name
}

output "debug_subnet_address_prefixes" {
  description = "The address prefixes of the created subnet"
  value       = local.dev_subnet_prefix
}

output "debug_nsg_id" {
  description = "The ID of the associated NSG"
  value       = azurerm_network_security_group.validation.id
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