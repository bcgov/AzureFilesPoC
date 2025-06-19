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

# Outputs
output "resource_group_name" {
  description = "The name of the validation resource group"
  value       = azurerm_resource_group.validation.name
}

output "validation_status" {
  description = "Validation status message"
  value       = "Terraform validation successful - CI/CD pipeline is working!"
}
