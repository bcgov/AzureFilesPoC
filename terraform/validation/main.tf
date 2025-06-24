/*
 * =================================================================================================
 *   Azure Files PoC - CI/CD and Terraform Validation Script
 * =================================================================================================
 *
 * PURPOSE:
 * This file is now updated to use a pre-existing Azure Resource Group, created via the onboarding
 * scripts in OneTimeActivities. All resources are deployed into this resource group.
 *
 * PRE-REQUISITE:
 * The resource group must be created in advance using the onboarding scripts.
 * The service principal (or your local user) running this script MUST have
 * the 'Contributor' role on the resource group (or subscription) to succeed.
 *
 */

# Configure the Azure and AzAPI providers, and set the required Terraform version.
terraform {
  required_version = "~> 1.0"

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
variable "environment" {
  description = "The target environment, e.g., 'dev'."
  type        = string
}

variable "dev_resource_group" {
  description = "The name of the pre-existing resource group to use for validation. Must be created in onboarding."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# Local variables
locals {
  project_prefix = "ag-pssg-azure-poc"
  env            = var.environment
}

# Reference the existing resource group (created in onboarding)
data "azurerm_resource_group" "validation" {
  name = var.dev_resource_group
}

# --- All other resources can now use data.azurerm_resource_group.validation.name and .location ---

# Example: Uncomment and update the following resources as needed
# resource "azurerm_network_security_group" "validation" {
#   name                = "nsg-${local.project_prefix}-${local.env}-01"
#   location            = data.azurerm_resource_group.validation.location
#   resource_group_name = data.azurerm_resource_group.validation.name
#   tags                = var.common_tags
# }

# # Reference the existing VNet
# data "azurerm_virtual_network" "existing" {
#   ...
# }

# # Create subnet using AzAPI with NSG association
# resource "azapi_resource" "storage_pe_subnet" {
#   ...
# }

# # Create the Storage Account.
# resource "azurerm_storage_account" "validation" {
#   ...
# }

# # Create the Private Endpoint.
# resource "azurerm_private_endpoint" "storage_pe" {
#   ...
# }

# --- Outputs for all resources ---
output "resource_group_name" {
  description = "The name of the validation resource group (pre-existing)"
  value       = data.azurerm_resource_group.validation.name
}

# output "subnet_id" {
#   ...
# }

# output "storage_account_name" {
#   ...
# }

# output "storage_account_id" {
#   ...
# }

# output "storage_account_resource_group" {
#   ...
# }

# output "storage_account_location" {
#   ...
# }