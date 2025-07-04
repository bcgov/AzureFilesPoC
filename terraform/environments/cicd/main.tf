# --- terraform/environments/cicd/main.tf ---
#
# This file composes reusable modules using a consistent set of variables
# to build the 'cicd' environment for the self-hosted runner.
# This version is structured for step-by-step validation and troubleshooting.

# ==============================================================================
# SETUP STEPS FOR CI/CD ENVIRONMENT (REQUIRED MANUAL AND AUTOMATED STEPS)
# ------------------------------------------------------------------------------
# Preconditions / Assumptions (MUST BE COMPLETED BEFORE RUNNING TERRAFORM):
#   1. Complete Azure onboarding process (steps 1-7, 6.1, 6.2, 11):
#      - Azure AD application registration (step1_register_app.sh)
#      - Service principal permissions (step2_grant_subscription_level_permissions.sh)
#      - OIDC federation setup (step3_configure_github_oidc_federation.sh)
#      - GitHub secrets configuration (step4_prepare_github_secrets.sh, step5_add_github_secrets_cli.sh)
#      - Resource groups creation (step6_create_resource_group.sh)
#      - Custom roles creation (step6.1_CreateCustomRole.sh)
#      - Role assignments (step6.2_assign_roles_to_resource_group.sh)
#      - Terraform state storage (step7_create_tfstate_storage_account.sh)
#      - SSH key generation (step11_create_ssh_key.sh)
#
#   2. Resource group for CI/CD (e.g., rg-<project-name>-cicd-tools-dev) is pre-created. (✅ done)
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh
#
#   3. SSH key pair for VM admin access is generated and public key is registered as a GitHub secret. (✅ done)
#      - Created using: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step11_create_ssh_key.sh
#      - Public key stored in GitHub secret: ADMIN_SSH_KEY_PUBLIC
#      - Private key stored locally: ~/.ssh/id_rsa (for Bastion access)
#
#   4. Service principal has required permissions on subscription and resource groups. (✅ done)
#      - Subscription-level: Reader, Network Contributor (limited scope)
#      - Resource group-level: Contributor, custom role assignments
#      - Created by: step2, step6.1, step6.2 scripts
#
#   5. GitHub repository configured with secrets and OIDC federation. (✅ done)
#      - AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID
#      - ADMIN_SSH_KEY_PUBLIC, resource group names, state storage details
#      - OIDC federated credentials configured in Azure AD
#
#   6. Terraform backend storage account and containers exist. (✅ done)
#      - Storage account: <storage-account-name>
#      - Container for CICD: <container-name>-cicd
#      - Created by: step7_create_tfstate_storage_account.sh + manual container creation
#
#   7. All names and address spaces are set in terraform.tfvars. (✅ done)
#      - CICD resource group name, networking configuration, VM settings
#
#   8. BC Gov Azure Landing Zone networking resources exist. (✅ done)
#      - VNet: <ministry-code>-<environment>-vwan-spoke in <ministry-code>-<environment>-networking resource group
#      - Address space and DNS servers configured
#
# DEPLOYMENT STEPS (AFTER COMPLETING ALL PRECONDITIONS ABOVE):
#
# Step 1. (✅ COMPLETED): Complete Full Azure Onboarding Process
#   - All foundational setup completed via onboarding scripts (steps 1-7, 6.1, 6.2, 11)
#   - Service principal, OIDC, GitHub secrets, resource groups, roles, SSH keys all configured
#   STATUS: ✅ completed during onboarding
#
# Step 2. (✅ COMPLETED): Validate Terraform Configuration Locally
#   - Fixed variable naming consistency and module compatibility issues
#   - Created missing backend container and reinitialized state
#   - Verified terraform validate, plan working correctly
#   STATUS: ✅ completed during validation
#
# Step 3. (READY): Deploy CI/CD Infrastructure via GitHub Actions
#   - Push changes to trigger GitHub Actions workflow
#   - Monitor deployment of NSGs, subnets, Bastion host, and runner VM
#   - Validate all resources created successfully
#   STATUS: ⏳ ready for deployment
# 
# ==============================================================================
# ONBOARDING SCRIPTS REFERENCE (REQUIRED PREREQUISITES)
# ------------------------------------------------------------------------------
# All preconditions above are completed using these onboarding scripts:
# 
# Location: OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/
# 
# Core Identity & Authentication:
#   - step1_register_app.sh                        # Azure AD app registration
#   - step2_grant_subscription_level_permissions.sh # Service principal permissions  
#   - step3_configure_github_oidc_federation.sh     # OIDC federation setup
#   - step4_prepare_github_secrets.sh               # Extract secret values
#   - step5_add_github_secrets_cli.sh               # Automated GitHub secret creation
# 
# Resource Groups & Roles:
#   - step6_create_resource_group.sh                # Create all resource groups
#   - step6.1_CreateCustomRole.sh                   # Create custom Azure roles
#   - step6.2_assign_roles_to_resource_group.sh     # Assign roles to service principal
# 
# Infrastructure Backend:
#   - step7_create_tfstate_storage_account.sh       # Terraform state storage
# 
# VM Access:
#   - step11_create_ssh_key.sh                      # SSH key generation for VMs
# 
# Documentation:
#   - TROUBLESHOOTING_GUIDE.md                      # Comprehensive troubleshooting
#   - SSH_KEY_REFERENCE.md                          # SSH key management guide
# ==============================================================================
# 
# ==============================================================================
# ADDITIONAL VALIDATION STEPS PERFORMED (July 2025)
# ------------------------------------------------------------------------------
# During local validation before GitHub Actions deployment, the following 
# configuration fixes were required:
#
# 1. VARIABLE NAMING CONSISTENCY:
#    - Fixed duplicate variable declarations in variables.tf
#    - Aligned module variable names (location vs azure_location) 
#    - Updated module calls to use correct variable mapping
#
# 2. TERRAFORM STATE BACKEND SETUP:
#    - Created missing blob container for CICD environment:
#      az storage container create --name "<container-name>-cicd" 
#        --account-name "<storage-account-name>" --auth-mode login
#    - Reinitialized backend with correct configuration:
#      terraform init -backend-config="resource_group_name=<rg>" -backend-config="storage_account_name=<sa>" -backend-config="container_name=<container>"
#
# 3. MODULE COMPATIBILITY:
#    - Updated bastion/nsg, runner/nsg, and vm modules to use consistent 
#      variable names (location instead of azure_location)
#    - Verified module variable declarations match usage
#
# VALIDATION WORKFLOW:
#   cd terraform/environments/<environment>
#   terraform init -backend-config="resource_group_name=<rg>" -backend-config="storage_account_name=<sa>" -backend-config="container_name=<container>"
#   terraform validate              # Check syntax and structure
#   terraform plan -var-file="../../terraform.tfvars" -out=tfplan  # Preview changes
#   terraform apply tfplan          # Apply locally for validation
#   git commit && git push          # Deploy via GitHub Actions for production
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
    # NOTE: Backend configuration comes from CLI parameters
    # If you encounter state storage errors during init, ensure:
    # 1. The blob container exists (created by validation steps above)
    # 2. Backend values are provided via CLI parameters
    # 3. Run: terraform init -backend-config="resource_group_name=<rg>" -backend-config="storage_account_name=<sa>" -backend-config="container_name=<container>"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

# ===============================================================================
# SECTION 1: CORE RESOURCE GROUP (DATA SOURCE)
# -------------------------------------------------------------------------------
# Resource groups are pre-created by the BC Gov landing zone/central IT or onboarding scripts.
# Service principals and Terraform are NOT authorized to create resource groups.
# Reference the pre-created resource group by name (var.cicd_resource_group_name).
# this script is created by step6_create_resource_group.sh
# -------------------------------------------------------------------------------
data "azurerm_resource_group" "main" {
  name = var.cicd_resource_group_name
}

# ===============================================================================
# SECTION 2: RBAC ASSIGNMENTS (GITHUB ACTIONS SERVICE PRINCIPAL)
# ------------------------------------------------------------------------------
# NOTE: Role assignments are handled by onboarding scripts, not Terraform.
# The service principal already has the following permissions assigned:
#   - Network Contributor (for networking resources)
#   - Virtual Machine Contributor (for VM resources)  
#   - Managed Identity Operator (for VM managed identities)
#   - [<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer (for role assignments)
#   - Storage Account Contributor (inherited from subscription level)
#
# If additional role assignments are needed, use the onboarding scripts:
#   OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6.2_assign_roles_to_resource_group.sh
# ------------------------------------------------------------------------------

# Commented out - role assignments handled by onboarding scripts
# resource "azurerm_role_assignment" "github_actions_network_contributor" {
#   scope                = data.azurerm_resource_group.main.id
#   role_definition_name = "Network Contributor"
#   principal_id         = var.my_github_actions_spn_object_id
# }

# ===============================================================================
# SECTION 3: CORE NETWORKING (DATA SOURCES)
# -------------------------------------------------------------------------------
# 3.1 Look up the pre-existing Spoke VNet
# -------------------------------------------------------------------------------
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group
}

# ===============================================================================
# SECTION 4: NETWORK SECURITY GROUPS (NSG) and subnets
# -------------------------------------------------------------------------------
# 4.1 Runner NSG: Pre-created and referenced as a data source above
# 4.2 Bastion NSG: Created and managed by bastion/nsg module
#                  Confirmed working with github actions.  don't need to run 
#                  shell script. 
# NOTE: Module variable mapping - modules expect 'location' parameter, 
#       main.tf passes var.azure_location (from terraform.tfvars)
# -------------------------------------------------------------------------------
module "bastion_nsg" {
  source                = "../../modules/bastion/nsg"
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = var.azure_location  # Maps azure_location -> location in module
  nsg_name              = var.bastion_network_security_group
  tags                  = var.common_tags
  vnet_id               = var.vnet_id
  address_prefix        = var.bastion_address_prefix[0]
  subnet_name           = var.bastion_subnet_name
}


# --- Runner NSG and Subnet (Automated, Policy-Compliant) ---
module "runner_nsg" {
  source              = "../../modules/runner/nsg"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.azure_location  # Maps azure_location -> location in module
  nsg_name            = var.runner_network_security_group
  tags                = var.common_tags
  vnet_id             = var.vnet_id
  address_prefix      = var.runner_vnet_address_space[0]
  subnet_name         = var.runner_subnet_name
  # ssh_allowed_cidr  = var.runner_ssh_allowed_cidr # Uncomment if you want to allow SSH inbound
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
  bastion_name          = var.bastion_name
  public_ip_name        = var.bastion_public_ip_name
  subnet_id             = module.bastion_nsg.bastion_subnet_id
}

# ===============================================================================
# SECTION 6: SELF-HOSTED RUNNER VM
# -------------------------------------------------------------------------------
# 6.1 Deploy the Self-Hosted Runner VM using your existing module
#    - Uncomment this section after confirming previous steps.
# NOTE: VM module expects 'location' parameter, uses data source location 
#       (which resolves to the same azure_location value)
# -------------------------------------------------------------------------------
module "self_hosted_runner_vm" {
  source                = "../../modules/vm"
  vm_name               = var.runner_vm_name
  resource_group_name   = data.azurerm_resource_group.main.name
  location              = data.azurerm_resource_group.main.location  # Uses data source location
  subnet_id             = module.runner_nsg.runner_subnet_id
  admin_ssh_key_public  = var.admin_ssh_key_public
  tags                  = var.common_tags
  vm_size               = var.runner_vm_size
  # Add other required variables as needed
}
# ===============================================================================
# SECTION 7: OUTPUTS (RECOMMENDED)
# -------------------------------------------------------------------------------
# Outputs are defined in outputs.tf for easier reference and troubleshooting in CI/CD pipelines.
# See outputs.tf for implementation.
# -------------------------------------------------------------------------------
