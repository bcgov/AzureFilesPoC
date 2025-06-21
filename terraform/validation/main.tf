/* 
 * Azure Files PoC - Terraform Validation Configuration
 * Purpose: Minimal Terraform configuration to validate CI/CD integration
 * 
 * This configuration creates only a simple resource group and tag for validation.
 * It's designed to validate authentication, permissions, and workflows without 
 * creating any significant Azure resources or incurring costs.
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

# Local variables
locals {
  validation_name = "azfiles-poc-validation-${var.environment}"
  common_tags = {
    Project     = "Azure Files PoC"
    Environment = var.environment
    Purpose     = "Validation"
    Terraform   = "true"
  }
}

# Simple resource group for validation
resource "azurerm_resource_group" "validation" {
  name     = "rg-${local.validation_name}"
  location = var.location
  tags     = local.common_tags
  
  # Lifecycle policy to prevent accidental deletion
  lifecycle {
    prevent_destroy = false
  }
}

# The following resources are commented out for permission testing
/*
# Storage account for blob validation
resource "azurerm_storage_account" "validation" {
  name                     = "st${replace(local.validation_name, "-", "")}${formatdate("MMdd", timestamp())}"
  resource_group_name      = azurerm_resource_group.validation.name
  location                 = azurerm_resource_group.validation.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.common_tags
}

# Container for blob validation
resource "azurerm_storage_container" "validation" {
  name                  = "validation-container"
  storage_account_name  = azurerm_storage_account.validation.name
  container_access_type = "private"
}

# Hello World blob for validation
resource "azurerm_storage_blob" "hello_world" {
  name                   = "hello-world.txt"
  storage_account_name   = azurerm_storage_account.validation.name
  storage_container_name = azurerm_storage_container.validation.name
  type                   = "Block"
  source_content         = "Hello, World! This is a test file created by Terraform to validate GitHub Actions with OIDC authentication to Azure."
}
*/

# Outputs
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

/*
output "storage_account_name" {
  description = "The name of the validation storage account"
  value       = azurerm_storage_account.validation.name
}

output "blob_url" {
  description = "The URL of the hello-world blob"
  value       = "${azurerm_storage_account.validation.primary_blob_endpoint}${azurerm_storage_container.validation.name}/${azurerm_storage_blob.hello_world.name}"
}
*/

output "validation_status" {
  description = "Validation status message"
  value       = "Terraform validation successful - CI/CD pipeline is working!"
}
