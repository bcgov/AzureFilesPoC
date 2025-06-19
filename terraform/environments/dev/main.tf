terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.0"
    }
  }
  
  # Backend configuration should be added here
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "bcgovtfstate"
  #   container_name       = "tfstate"
  #   key                 = "azurefiles/dev.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

provider "azapi" {
}

module "azure_files" {
  source = "../../modules/bc-gov-azure-files"

  resource_group_name      = var.resource_group_name
  location                = var.location
  storage_account_name    = var.storage_account_name
  file_share_name         = var.file_share_name
  file_share_quota_gb     = var.file_share_quota_gb
  vnet_name               = var.vnet_name
  vnet_address_space      = var.vnet_address_space
  subnet_name             = var.subnet_name
  subnet_address_prefixes = var.subnet_address_prefixes
  common_tags             = merge(var.common_tags, {
    environment = "dev"
  })
}
