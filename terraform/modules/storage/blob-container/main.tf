# Storage Blob Container with least-privilege RBAC

# This block is a best practice for modules to declare their provider requirements.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      # This module is now compatible with provider version 3.75.0
      version = ">= 3.0"
    }
  }
}

resource "azurerm_storage_container" "main" {
  name                  = var.container_name
  storage_account_name  = var.storage_account_name
  container_access_type = var.container_access_type
   # Corresponds to the metadata property
  metadata = var.metadata
}
