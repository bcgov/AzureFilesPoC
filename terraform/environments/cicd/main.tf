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
#   2. Network Security Group for runner subnet (e.g., nsg-github-runners) is pre-created. (done)
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step10_create_nsg.sh
#   3. Subnet for runner (e.g., snet-github-runners) is pre-created and associated with the NSG.
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step9_create_subnet.sh (with --nsg argument for association) (done)
#   4. SSH key pair for VM admin access is generated and public key is registered as a GitHub secret.
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
#   5. Any pre-existing Azure resources (such as subnet/NSG associations) are imported into Terraform state.
#      - Imported using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step12_import_existing_resources.sh
#   6. All names and address spaces are set in terraform.tfvars.(done)
#   7. All names and address spaces are set in github variables (done)
#
# Step 1. (Manual, One-Time): Create the CI/CD Resource Group
#   - Use your user identity and the onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh --rgname "<cicd-resource-group-name>" --location "<location>"
#   - This is required due to policy: resource groups cannot be created by Terraform or service principals.
#   - Reference the created resource group in your variables (var.dev_cicd_resource_group_name).
#   STATUS:  created
# 
# Step 2. (Manual, One-Time): Create the NSG for the runner subnet
#   - Use onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step10_create_nsg.sh --nsgname "<nsg-name>" --rg "<resource-group>" --location "<location>"
#   - Reference the created NSG in your variables (var.dev_runner_network_security_group).
#   STATUS:  created
#
# Step 3. (Manual, One-Time): Create the runner subnet and associate with NSG
#   - Use onboarding script:
#     bash OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step9_create_subnet.sh --vnetname "<vnet-name>" --vnetrg "<vnet-resource-group>" --subnetname "<subnet-name>" --addressprefix "<address-prefix>" --nsg "<nsg-name>"
#   - Reference the created subnet in your variables (var.dev_runner_subnet_name).
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
# 3.2 Look up the pre-existing Subnet for the runner
# 3.3 Look up the pre-existing NSG for the runner
# -------------------------------------------------------------------------------
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

data "azurerm_subnet" "runner_subnet" {
  name                 = var.dev_runner_subnet_name
  virtual_network_name = var.dev_vnet_name
  resource_group_name  = var.dev_vnet_resource_group
}

data "azurerm_network_security_group" "runner_nsg" {
  name                = var.dev_runner_network_security_group
  resource_group_name = var.dev_vnet_resource_group
}

# ===============================================================================
# SECTION 4: NETWORK SECURITY GROUPS (NSG)
# -------------------------------------------------------------------------------
# 4.1 Runner NSG: Pre-created and referenced as a data source above
# 4.2 Bastion NSG: Created and managed by bastion module
# -------------------------------------------------------------------------------
# (No resource block needed for runner NSG)

# ===============================================================================
# SECTION 5: AZURE BASTION HOST, network security group and subnet
# -------------------------------------------------------------------------------
# This module deploys Azure Bastion in the same VNet as the runner VM, providing
# secure browser-based SSH/RDP access without a public IP on the VM.
# The Bastion NSG, including all required inbound and outbound rules, and the Bastion subnet are both fully defined and managed inside the Bastion module (see modules/bastion/main.tf).
# To provision Bastion, the main module calls the Bastion module (see section 6.1 below), which creates the NSG, subnet (with NSG association), and Bastion host in the correct sequence.
# This ensures the NSG (with all Bastion-specific rules) is created first, then the subnet is created and associated with the NSG,
# and finally the Bastion Host is deployed. This sequence is required for Azure policy compliance and Bastion provisioning to succeed.
# (There is no Bastion NSG resource or rules defined in this root module. All Bastion NSG logic is in the Bastion module.)
# -------------------------------------------------------------------------------
# module "bastion" {
#   source                = "../../modules/bastion"
#   resource_group_name   = data.azurerm_resource_group.main.name
#   location              = data.azurerm_resource_group.main.location
#   vnet_name             = data.azurerm_virtual_network.spoke_vnet.name
#   vnet_resource_group   = data.azurerm_virtual_network.spoke_vnet.resource_group_name
#   bastion_name          = var.dev_bastion_name
#   public_ip_name        = var.dev_bastion_public_ip_name
#   address_prefix        = var.dev_bastion_address_prefix[0]
#   network_security_group = var.dev_bastion_network_security_group
# }

# ===============================================================================
# SECTION 6: NSG ASSOCIATION
# -------------------------------------------------------------------------------
# 6.1 Associate the NSG with the runner's subnet
# -------------------------------------------------------------------------------
# This resource enforces and maintains the association between the specified
# Network Security Group (NSG) and the runner subnet. Even if the NSG was
# associated with the subnet during manual onboarding (via shell script),
# Terraform will ensure the association is present and correct as part of the
# infrastructure state. If the association is missing or different, Terraform
# will create or update it to match this configuration. If removed from the
# configuration, Terraform will remove the association in Azure.
#
# Purpose:
# - Ensures the runner subnet is always protected by the intended NSG.
# - Maintains idempotency and drift correction: if the association is changed
#   outside of Terraform, it will be restored on the next apply.
# - Allows for safe, repeatable infrastructure automation and compliance.
resource "azurerm_subnet_network_security_group_association" "runner_nsg_assoc" {
  subnet_id                 = data.azurerm_subnet.runner_subnet.id
  network_security_group_id = data.azurerm_network_security_group.runner_nsg.id
}

# 6.2 Associate the NSG with the Bastion subnet
# This resource enforces and maintains the association between the Bastion NSG and the Bastion subnet.
# Ensures policy compliance: every subnet must have an NSG. If the Bastion subnet is created by the Bastion module,
# reference its output for the subnet ID. Adjust the reference if your module uses a different output name.
# resource "azurerm_subnet_network_security_group_association" "bastion_nsg_assoc" {
#   subnet_id                 = module.bastion.bastion_subnet_id
#   network_security_group_id = module.bastion.bastion_nsg_id
# }



# ===============================================================================
# SECTION 7: SELF-HOSTED RUNNER VM
# -------------------------------------------------------------------------------
# 7.1 Deploy the Self-Hosted Runner VM using your existing module
#    - Uncomment this section after confirming previous steps.
# -------------------------------------------------------------------------------
# module "self_hosted_runner_vm" {
#   source = "../../modules/vm"
#
#   vm_name               = var.dev_runner_vm_name
#   resource_group_name   = data.azurerm_resource_group.main.name
#   location              = data.azurerm_resource_group.main.location
#   subnet_id             = data.azurerm_subnet.runner_subnet.id
#   admin_ssh_key_public  = var.admin_ssh_key_public
#   tags                  = var.common_tags
#   depends_on = [
#     azurerm_subnet_network_security_group_association.runner_nsg_assoc
#   ]
# }
# ===============================================================================
# SECTION 8: OUTPUTS (RECOMMENDED)
# -------------------------------------------------------------------------------
# Outputs are defined in outputs.tf for easier reference and troubleshooting in CI/CD pipelines.
# See outputs.tf for implementation.
# -------------------------------------------------------------------------------

# TEST: Create a test NSG to verify if policy allows Terraform to create NSGs
resource "azurerm_network_security_group" "test_nsg" {
  name                = "test-cicd-nsg"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags = {
    environment = "test"
    managed_by  = "terraform"
  }
}

# TEST: Create a test subnet and associate with test-cicd-nsg to verify Terraform permissions
resource "azurerm_subnet" "test_subnet" {
  name                 = "test-cicd-subnet"
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = data.azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = ["10.46.73.240/28"] # Use a non-overlapping range
}

resource "azurerm_subnet_network_security_group_association" "test_subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.test_subnet.id
  network_security_group_id = azurerm_network_security_group.test_nsg.id
}