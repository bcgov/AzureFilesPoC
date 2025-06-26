# --- terraform/environments/dev/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'dev' environment.

terraform {
  required_version = ">= 1.6.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    # Add the time provider to manage delays for permission propagation.
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }

  backend "azurerm" {
    key = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

#================================================================================
# NEW VARIABLE FOR GITHUB RUNNER IP
#================================================================================
# This variable will be populated by the -var="allowed_ip_rules=[...]" argument
# in the GitHub Actions workflow.
variable "allowed_ip_rules" {
  type        = list(string)
  description = "A list of public IP CIDR ranges to allow through the storage account firewall, passed from the CI/CD pipeline."
  default     = []
}

#================================================================================
# IDENTITY AND PERMISSIONS
#================================================================================
data "azurerm_client_config" "current" {}

# This role is for DATA PLANE access (reading/writing files). It's still good to have.
resource "azurerm_role_assignment" "storage_data_contributor" {
  scope                = module.poc_storage_account.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# This resource introduces a delay to allow Azure IAM permissions to propagate
# before attempting to create the file share.
resource "time_sleep" "wait_for_iam_propagation" {
  create_duration = "30s"

  # The trigger ensures the sleep only happens after the role assignment is complete.
  triggers = {
    role_assignment_id = azurerm_role_assignment.storage_data_contributor.id
  }
}

#================================================================================
# MODULES
#================================================================================

# 1. Create the secure storage account.
module "poc_storage_account" {
  source = "../../modules/storage/account"

  storage_account_name = var.dev_storage_account_name
  resource_group_name  = var.dev_resource_group
  location             = var.azure_location
  tags                 = var.common_tags

  # Pass the runner's IP address to the module so it can create a firewall rule.
  allowed_ip_rules = var.allowed_ip_rules
}

# 2. Create the file share in the storage account.
module "poc_file_share" {
  source = "../../modules/storage/file-share"

  # --- Required Arguments ---
  file_share_name      = var.dev_file_share_name
  storage_account_name = module.poc_storage_account.name
  quota_gb             = var.dev_file_share_quota_gb

  # --- Optional Arguments ---
  enabled_protocol = "SMB"
  access_tier      = "TransactionOptimized"
  metadata         = {}

  # The 'depends_on' block is critical. It forces Terraform to wait until
  # the time_sleep resource (which waits for the role assignment) is complete.
  depends_on = [
    time_sleep.wait_for_iam_propagation
  ]
}

# --- The following resources are commented out for initial setup ---
# (No changes needed for the commented-out code)
# # Use the subnet module to create the dedicated subnet in the existing VNet.
# module "private_endpoint_subnet" { ... }
#
# # Use the private endpoint module to connect the storage account to the subnet.
# module "storage_private_endpoint" { ... }