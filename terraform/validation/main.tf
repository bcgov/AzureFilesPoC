/* 
 * Azure Files PoC - Terraform Validation Configuration
 * Purpose: Minimal Terraform configuration to validate CI/CD integration
 *
 * Dependencies:
 *   - Authenticate with Azure using 'az login' (no client secret needed for OIDC/GitHub Actions)
 *   - Variable values are sourced from terraform.tfvars (see terraform.tfvars.template for structure)
 *   - If using service principal authentication, values can be provided in secrets.tfvars (see secrets.tfvars.template)
 *
 * Step 1:
 * This configuration creates only a simple resource group for validation.
 * It's designed to validate authentication, permissions, and workflows without 
 * creating any significant Azure resources or incurring costs.
 *
 * Step 2:
 * Uncomment and validate each resource in the following recommended sequence, skipping any that already exist in your environment:
 *   i.   Network Security Group (NSG) for validation subnet (create if not present)
 *   ii.  Subnet (using AzAPI, with NSG association, create in existing VNet)
 *   iii. Storage Account (with public network access disabled and network rules referencing the subnet)
 *   iv.  Blob Container (in the storage account)
 *   v.   Test Blob file (in the container)
 *
 *   Note: Do NOT create the VNet or resource group if they already exist. Reference them using data sources and variables populated from .env/azure-full-inventory.json and your tfvars files.
 *
 * This incremental approach helps identify policy or permission issues at each stage and ensures compliance with BC Gov Azure Landing Zone requirements.
 */

# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  # We're keeping the backend as local for this validation module
  # In a production setup, you would configure a remote backend
}

provider "azurerm" {
  features {}
}

# Variables
variable "location" {
  description = "The Azure region for resources"
  type        = string
  default     = "canadacentral"
}

variable "environment" {
  description = "Environment (dev, test, prod)"
  type        = string
  default     = "dev"
}

# Variable declarations in `main.tf` inform Terraform about the input variables it should expect.
# When a variable is declared in this way, Terraform can automatically assign its value from a corresponding entry in `terraform.tfvars` (or other variable definition files) if present.
# This allows you to separate variable values from your configuration, making your code more reusable and easier to manage.
variable "resource_group" {
  description = "The name of the resource group to use"
  type        = string
}
# This variable is expected to be defined in terraform.tfvars or another tfvars file.
variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
}

variable "vnet_name" {
  description = "The name of the existing virtual network"
  type        = string
}

variable "subnet_name" {
  description = "The name of the subnet to create in the existing VNet"
  type        = string
}

variable "subnet_address_prefixes" {
  description = "The address prefixes for the subnet"
  type        = list(string)
}



# Local variables
locals {
  project_prefix = "ag-pssg-azure-poc"
  env = var.environment
  rg_name = "rg-${local.project_prefix}-${local.env}"
  st_name = lower(replace("st${local.project_prefix}${local.env}01", "-", ""))
  sc_name = "sc-${local.project_prefix}-${local.env}-01"
  validation_tags = {
    Project     = "Azure Files PoC"
    Environment = var.environment
    Purpose     = "Validation"
    Terraform   = "true"
  }
}

# Simple resource group for validation
resource "azurerm_resource_group" "validation" {
  name     = local.rg_name
  location = var.location
  tags     = local.validation_tags
  
  # Lifecycle policy to prevent accidental deletion
  lifecycle {
    prevent_destroy = false
  }
}

# Uncomment the following resources one at a time for incremental validation.

# Network Security Group (NSG) for validation subnet
# Only the resource_group_name is required; subscription is determined by the provider configuration or your Azure CLI context.
resource "azurerm_network_security_group" "validation" {
  name                = "nsg-${local.project_prefix}-${local.env}-01"
  location            = var.location
  resource_group_name = var.resource_group
  tags                = var.common_tags
}

# Reference the existing VNet using a data block
# NOTE: The Virtual Network (VNet) is not created by this module. It is expected to already exist as part of your environment (e.g., provided by your platform or landing zone). 
# Only reference the existing VNet using a data source and variables. Do not attempt to create a new VNet here.
data "azurerm_virtual_network" "existing" {
  name                = var.vnet_name
  resource_group_name = var.resource_group
}

# Create a new subnet in the existing VNet
resource "azurerm_subnet" "validation" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group
  virtual_network_name = data.azurerm_virtual_network.existing.name
  address_prefixes     = var.subnet_address_prefixes
}

# --- VNet creation block intentionally omitted ---
# The following block is not used. VNet creation is managed outside this module.
#use the one that comes with the subscription
# resource "azurerm_virtual_network" "validation" {
#   name                = "vnet-${local.project_prefix}-${local.env}-01"
#   address_space       = ["10.10.0.0/16"]
#   location            = azurerm_resource_group.validation.location
#   resource_group_name = azurerm_resource_group.validation.name
#   tags                = local.validation_tags
# }

# # Subnet with NSG association using AzAPI
# resource "azapi_resource" "validation_subnet" {
#   type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
#   name      = "subnet-validation"
#   parent_id = azurerm_virtual_network.validation.id
#   body = jsonencode({
#     properties = {
#       addressPrefix = "10.10.1.0/24"
#       networkSecurityGroup = {
#         id = azurerm_network_security_group.validation.id
#       }
#     }
#   })
#   response_export_values = ["*"]
# }

# # Storage account for blob validation
# resource "azurerm_storage_account" "validation" {
#   name                     = local.st_name
#   resource_group_name      = azurerm_resource_group.validation.name
#   location                 = azurerm_resource_group.validation.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   public_network_access_enabled = false
#   network_rules {
#     default_action             = "Deny"
#     bypass                     = ["AzureServices"]
#     virtual_network_subnet_ids = [azapi_resource.validation_subnet.id]
#   }
#   tags = local.validation_tags
# }

# # Container for blob validation
# resource "azurerm_storage_container" "validation" {
#   name                  = local.sc_name
#   storage_account_name  = azurerm_storage_account.validation.name
#   container_access_type = "private"
# }

# # Hello World blob for validation
# resource "azurerm_storage_blob" "hello_world" {
#   name                   = "hello-world.txt"
#   storage_account_name   = azurerm_storage_account.validation.name
#   storage_container_name = azurerm_storage_container.validation.name
#   type                   = "Block"
#   source_content         = "Hello, World! This is a test file created by Terraform to validate GitHub Actions with OIDC authentication to Azure."
# }

# Outputs
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

# output "storage_account_name" {
#   description = "The name of the validation storage account"
#   value       = azurerm_storage_account.validation.name
# }

# output "blob_url" {
#   description = "The URL of the hello-world blob"
#   value       = "${azurerm_storage_account.validation.primary_blob_endpoint}${azurerm_storage_container.validation.name}/${azurerm_storage_blob.hello_world.name}"
# }

# output "validation_status" {
#   description = "Validation status message"
#   value       = "Terraform validation successful - CI/CD pipeline is working!"
# }
