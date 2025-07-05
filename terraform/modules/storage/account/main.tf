# In /terraform/modules/storage/account/main.tf

# This block is a Terraform best practice, ensuring the module declares the
# providers it depends on. This was added to resolve earlier validation errors.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  tags                = var.tags

  account_tier             = "Standard"
  account_replication_type = "LRS"
  large_file_share_enabled = true

  # This is the key setting to comply with the BC Gov policy that all
  # PaaS services must be private. It disables the public endpoint.
  public_network_access_enabled = false

  # The 'network_rules' block has been COMPLETELY REMOVED.
  #
  # This block is only used for configuring the firewall of the *public* endpoint.
  # Its presence, even while `public_network_access_enabled` was false, sent a
  # conflicting signal to the Azure API. The strict BC Government Policy saw
  # this as an attempt to configure a public IP feature and immediately
  # denied the resource creation with a 'RequestDisallowedByPolicy' error.
  #
  # By removing this block, our intent is clear: create a private-only storage
  # account. Access will be handled exclusively by the 'azurerm_private_endpoint'
  # resource defined in the root `dev/main.tf` module.
}