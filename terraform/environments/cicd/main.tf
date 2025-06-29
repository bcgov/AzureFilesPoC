# --- terraform/environments/cicd/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'cicd' environment for the self-hosted runner.
# This version is structured for step-by-step validation and troubleshooting.

# ==============================================================================
# SETUP STEPS FOR CI/CD ENVIRONMENT (REQUIRED MANUAL AND AUTOMATED STEPS)
# ------------------------------------------------------------------------------
# Preconditions / Assumptions:
#   1. Resource group for CI/CD (e.g., rg-ag-pssg-cicd-tools-dev) is pre-created.
#   2. Network Security Group for runner subnet (e.g., nsg-github-runners) is pre-created.
#   3. Subnet for runner (e.g., snet-github-runners) is pre-created and associated with the NSG.
#   4. All names and address spaces are set in terraform.tfvars.
#
# Step 1. (Manual, One-Time): Create the CI/CD Resource Group
#   - Use your user identity and the onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh --rgname "<cicd-resource-group-name>" --location "<location>"
#   - This is required due to policy: resource groups cannot be created by Terraform or service principals.
#   - Reference the created resource group in your variables (var.dev_cicd_resource_group_name).
#
# Step 2. (Manual, One-Time): Create the NSG for the runner subnet
#   - Use onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step10_create_nsg.sh --nsgname "<nsg-name>" --rg "<resource-group>" --location "<location>"
#   - Reference the created NSG in your variables (var.dev_runner_network_security_group).
#
# Step 3. (Manual, One-Time): Create the runner subnet and associate with NSG
#   - Use onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step9_create_subnet.sh --vnetname "<vnet-name>" --vnetrg "<vnet-resource-group>" --subnetname "<subnet-name>" --addressprefix "<address-prefix>" --nsg "<nsg-name>"
#   - Reference the created subnet in your variables (var.dev_runner_subnet_name).
#
# Step 4. (Automated): Run Terraform to Deploy the Self-Hosted Runner
#   - Each substep can be validated incrementally with `terraform plan` and `terraform apply`.
#   - For full onboarding and troubleshooting, see README.md and cicd/README.md.
# ==============================================================================

terraform {
  required_version = ">= 1.6.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  backend "azurerm" {
    key = "cicd.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

# ===============================================================================
# SECTION 1: CORE RESOURCE GROUP (DATA SOURCE)
# -------------------------------------------------------------------------------
# Resource groups are pre-created by the BC Gov landing zone/central IT or onboarding scripts.
# Service principals and Terraform are NOT authorized to create resource groups.
# Reference the pre-created resource group by name (var.dev_cicd_resource_group_name).
# this script is created by step6_create_resource_group.sh
# -------------------------------------------------------------------------------
data "azurerm_resource_group" "main" {
  name = var.dev_cicd_resource_group_name
}

# ===============================================================================
# SECTION 2: CORE NETWORKING (DATA SOURCES)
# -------------------------------------------------------------------------------
# 2.1 Look up the pre-existing Spoke VNet
# 2.2 Look up the pre-existing Subnet for the runner
# 2.3 Look up the pre-existing NSG for the runner
# -------------------------------------------------------------------------------
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

data "azurerm_subnet" "runner_subnet" {
  name                 = var.dev_runner_subnet_name
  virtual_network_name = data.azurerm_virtual_network.spoke_vnet.name
  resource_group_name  = data.azurerm_virtual_network.spoke_vnet.resource_group_name
}

data "azurerm_network_security_group" "runner_nsg" {
  name                = var.dev_runner_network_security_group
  resource_group_name = var.dev_vnet_resource_group
}

# ===============================================================================
# SECTION 3: NETWORK SECURITY GROUP (NSG)
# -------------------------------------------------------------------------------
# 3.1 (No-op) NSG is pre-created and referenced as a data source above
# -------------------------------------------------------------------------------
# (No resource block needed)

# ===============================================================================
# SECTION 4: NSG ASSOCIATION
# -------------------------------------------------------------------------------
# 4.1 Associate the NSG with the runner's subnet
# -------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "runner_nsg_assoc" {
  subnet_id                 = data.azurerm_subnet.runner_subnet.id
  network_security_group_id = data.azurerm_network_security_group.runner_nsg.id
}

# ===============================================================================
# SECTION 5: SELF-HOSTED RUNNER VM
# -------------------------------------------------------------------------------
# 5.1 Deploy the Self-Hosted Runner VM using your existing module
#    - Uncomment this section after confirming previous steps.
# -------------------------------------------------------------------------------
module "self_hosted_runner_vm" {
  source = "../../modules/vm"

  vm_name               = var.dev_runner_vm_name
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  subnet_id             = data.azurerm_subnet.runner_subnet.id
  admin_ssh_key_public  = file(var.admin_ssh_key_public_path)
  tags                  = var.common_tags
  # ... and any other variables your vm module needs ...

  depends_on = [
    azurerm_subnet_network_security_group_association.runner_nsg_assoc
  ]
}

# ===============================================================================
# SECTION 6: OUTPUTS (RECOMMENDED)
# -------------------------------------------------------------------------------
# Add outputs for easier reference and troubleshooting in CI/CD pipelines.
# Example outputs (add to outputs.tf):
# output "runner_vm_private_ip" {
#   value = module.self_hosted_runner_vm.private_ip_address
# }
# output "runner_vm_public_ip" {
#   value = module.self_hosted_runner_vm.public_ip_address
# }
# output "runner_resource_group" {
#   value = data.azurerm_resource_group.main.name
# }
# output "runner_nsg_name" {
#   value = azurerm_network_security_group.runner_nsg.name
# }
# output "runner_subnet_id" {
#   value = data.azurerm_subnet.runner_subnet.id
# }
# -------------------------------------------------------------------------------
# See outputs.tf for implementation.
# ===============================================================================