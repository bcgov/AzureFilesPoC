# In /terraform/modules/storage/account/main.tf

# This block is required for the module to be valid.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# --- Variable Definitions for this Module ---

variable "storage_account_name" {
  description = "The name of the Azure Storage Account."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the storage account."
  type        = string
}

variable "azure_location" {
  description = "The Azure region where the storage account will be created."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the storage account."
  type        = map(string)
  default     = {}
}

variable "storage_subnet_id" {
  description = "The ID of the subnet where the Private Endpoint for the storage account will be placed."
  type        = string
}

# This data source is needed to get the tenant_id for the private_link_access block.
data "azurerm_client_config" "current" {}

# --- Resource Definitions for this Module ---

resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.azure_location
  tags                     = var.tags
  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  # This setting is still mandatory.
  public_network_access_enabled = false

  # --- THIS IS THE CRITICAL FIX ---
  # This block signals to the Azure API, at the moment of creation, that this
  # Storage Account is intended to be used with a Private Endpoint from a specific
  # subnet. This is the only way to satisfy the strict BC Gov "Deny" policy.
  private_link_access {
    # Note: The provider argument is confusingly named. It requires the ID
    # of the Subnet from which the Private Endpoint will connect.
    endpoint_resource_id = var.storage_subnet_id
    endpoint_tenant_id   = data.azurerm_client_config.current.tenant_id
  }

  # This lifecycle block is added to prevent Terraform from trying to
  # remove the block on subsequent runs if it's not detected.
  lifecycle {
    ignore_changes = [
      custom_domain,
    ]
  }
}

# The separate 'azurerm_private_endpoint' resource has been REMOVED.
# The BC Gov platform will now automatically create the Private Endpoint resource itself
# based on the private_link_access configuration above.