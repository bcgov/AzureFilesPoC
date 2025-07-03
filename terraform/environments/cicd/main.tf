# --- terraform/environments/cicd/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'cicd' environment for the self-hosted runner.
# This version is structured for step-by-step validation and troubleshooting.

# ==============================================================================
# SETUP STEPS FOR CI/CD ENVIRONMENT (REQUIRED MANUAL AND AUTOMATED STEPS)
# ------------------------------------------------------------------------------
# Preconditions / Assumptions:
#   1. Resource group for CI/CD (e.g., rg-ag-pssg-cicd-tools-dev) is pre-created. (done)
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh
#   2. Network Security Group for runner subnet (e.g., nsg-github-runners) is created by Terraform pipeline (automated, policy-compliant)
#      - Created by: module.runner_nsg (see below)
#   3. Subnet for runner (e.g., snet-github-runners) is created and associated with the NSG by Terraform pipeline (automated, policy-compliant)
#      - Created by: module.runner_nsg (see below)
#   4. SSH key pair for VM admin access is generated and public key is registered as a GitHub secret.
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
#   5. All names and address spaces are set in terraform.tfvars. (done)
#   6. All names and address spaces are set in github variables. (done)
#
# Step 1. (Manual, One-Time): Create the CI/CD Resource Group
#   - Use your user identity and the onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh --rgname "<cicd-resource-group-name>" --location "<location>"
#   - This is required due to policy: resource groups cannot be created by Terraform or service principals.
#   - Reference the created resource group in your variables (var.dev_cicd_resource_group_name).
#   STATUS:  created
# 
# Step 2. (Automated): Create the NSG and subnet for the runner
#   - Both are created and associated in a single step by the Terraform pipeline (module.runner_nsg).
#   - No manual onboarding scripts are required for these resources.
#   STATUS:  created by pipeline
#
# Step 3. (Manual, One-Time): Generate SSH key pair for VM admin access
#   - Use onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
#   - Register the public key as a GitHub secret.
#   STATUS:  created
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
      version = ">= 3.64.0"
    }
    # AzAPI provider is required to create subnets with NSG association in a single step,
    # which is necessary for BC Gov Azure Policy compliance (subnets must have an NSG at creation).
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.12.0"
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
# SECTION 2: RBAC ASSIGNMENTS (GITHUB ACTIONS SERVICE PRINCIPAL)
# ------------------------------------------------------------------------------
# This resource grants the GitHub Actions service principal Network Contributor
# rights on the CI/CD resource group, so it can manage networking resources.
#
# Ensure you set the correct object ID for the service principal in your tfvars file:
#   github_actions_spn_object_id = "<object-id>"
#
resource "azurerm_role_assignment" "github_actions_network_contributor" {
  # Scope: Assigns the Network Contributor role at the resource group level.
  # This is the ARM resource ID for the CI/CD resource group named in var.dev_cicd_resource_group_name.
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = var.dev_github_actions_spn_object_id
}

# ===============================================================================
# SECTION 3: CORE NETWORKING (DATA SOURCES)
# -------------------------------------------------------------------------------
# 3.1 Look up the pre-existing Spoke VNet
# -------------------------------------------------------------------------------
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

# ===============================================================================
# SECTION 4: NETWORK SECURITY GROUPS (NSG) and subnets
# -------------------------------------------------------------------------------
# 4.1 Runner NSG: Pre-created and referenced as a data source above
# 4.2 Bastion NSG: Created and managed by bastion/nsg module
#                  Confirmed working with github actions.  don't need to run 
#                  shell script. 
# -------------------------------------------------------------------------------
module "bastion_nsg" {
  source                = "../../modules/bastion/nsg"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  nsg_name              = var.dev_bastion_network_security_group
  tags                  = var.dev_common_tags
  vnet_id               = var.dev_vnet_id
  address_prefix        = var.dev_bastion_address_prefix[0]
  subnet_name           = var.dev_bastion_subnet_name
}


# --- Runner NSG and Subnet (Automated, Policy-Compliant) ---
module "runner_nsg" {
  source              = "../../modules/runner/nsg"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location
  nsg_name            = var.dev_runner_network_security_group
  tags                = var.dev_common_tags
  vnet_id             = var.dev_vnet_id
  address_prefix      = var.dev_runner_vnet_address_space[0]
  subnet_name         = var.dev_runner_subnet_name
  # ssh_allowed_cidr  = var.dev_runner_ssh_allowed_cidr # Uncomment if you want to allow SSH inbound
}

# ===============================================================================
# SECTION 5: BASTION 
# -------------------------------------------------------------------------------
# The Bastion subnet is created by the bastion/nsg module (using AzAPI for policy compliance).
# The Bastion host is created by the bastion module, which takes the subnet ID and NSG ID as inputs.
module "bastion" {
  source                = "../../modules/bastion"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  vnet_name             = data.azurerm_virtual_network.spoke_vnet.name
  vnet_resource_group   = data.azurerm_virtual_network.spoke_vnet.resource_group_name
  bastion_name          = var.dev_bastion_name
  public_ip_name        = var.dev_bastion_public_ip_name
  subnet_id             = module.bastion_nsg.bastion_subnet_id
}

# ===============================================================================
# SECTION 6: SELF-HOSTED RUNNER VM
# -------------------------------------------------------------------------------
# 6.1 Deploy the Self-Hosted Runner VM using your existing module
#    - Uncomment this section after confirming previous steps.
# -------------------------------------------------------------------------------
module "self_hosted_runner_vm" {
  source                = "../../modules/vm"
  vm_name               = var.dev_runner_vm_name
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location
  subnet_id             = module.runner_nsg.runner_subnet_id
  admin_ssh_key_public  = var.admin_ssh_key_public
  tags                  = var.dev_common_tags
  vm_size               = var.dev_runner_vm_size
  # Add other required variables as needed
}
# ===============================================================================
# SECTION 7: OUTPUTS (RECOMMENDED)
# -------------------------------------------------------------------------------
# Outputs are defined in outputs.tf for easier reference and troubleshooting in CI/CD pipelines.
# See outputs.tf for implementation.
# -------------------------------------------------------------------------------
