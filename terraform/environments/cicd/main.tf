# --- terraform/environments/cicd/main.tf ---
# This configuration bootstraps the dev environment's self-hosted runner.

# ===============================================================================
# NOTES: Dependencies, Pre-Requirements, and Outputs
# -------------------------------------------------------------------------------
# IMPORTANT: Resource groups are pre-created by the BC Gov landing zone/central IT or by onboarding scripts.
# Service principals and Terraform are NOT authorized to create resource groups.
# Reference the pre-created resource group by name (var.dev_cicd_resource_group_name) in all modules.
# Look up the pre-existing resource group using a data source.
# This READS data instead of trying to CREATE (write) the resource.
#
# To create the resource group, use the onboarding script:
#   OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step6_create_resource_group.sh
#   (Run as your user identity, not as a service principal.)
#
# PRE-REQUIREMENTS:
# - Resource group must already exist (see above)
# - An existing Spoke VNet and subnet in Azure (referenced by var.dev_vnet_name, var.dev_vnet_resource_group, var.dev_runner_subnet_name)
# - The subnet must not have an existing NSG association (or you must be prepared to overwrite it)
# - Your public IP address (var.dev_my_home_ip_address) must be set for SSH access
# - SSH key pair must exist and the public key path provided (var.admin_ssh_key_public_path)
# - Sufficient Azure permissions to create NSGs and VMs in the target resource group
# - The VM module (../../modules/vm) must exist and be properly configured
# - Common tags (var.common_tags) and location (var.azure_location) must be set
#
# DEPENDENCIES:
# - data.azurerm_resource_group.main: Looks up the pre-existing resource group
# - data.azurerm_virtual_network.spoke_vnet: Looks up the existing VNet
# - data.azurerm_subnet.runner_subnet: Looks up the existing subnet
# - azurerm_network_security_group.runner_nsg: NSG for the runner VM
# - azurerm_subnet_network_security_group_association.runner_nsg_assoc: Associates NSG with subnet
# - module.self_hosted_runner_vm: Deploys the VM, depends on NSG association
#
# OUTPUTS:
# - (Recommended) VM private IP, public IP (if created), resource group name, NSG name, subnet ID
# - These can be added as Terraform outputs for easier reference in CI/CD and troubleshooting
#
# RESOURCE CREATION SEQUENCE (in order):
# 1. data.azurerm_resource_group.main                # Looks up the pre-existing resource group
# 2. data.azurerm_virtual_network.spoke_vnet         # Looks up the existing Spoke VNet (data source, not created)
# 3. data.azurerm_subnet.runner_subnet               # Looks up the existing subnet (data source, not created)
# 4. azurerm_network_security_group.runner_nsg       # Creates a Network Security Group for the runner VM
# 5. azurerm_subnet_network_security_group_association.runner_nsg_assoc # Associates the NSG with the subnet
# 6. module.self_hosted_runner_vm                    # Deploys the self-hosted runner VM (and its dependencies, e.g., NIC, disk, public IP if defined in the module)
#
# RESOURCE TYPES CREATED:
# - azurerm_network_security_group
# - azurerm_subnet_network_security_group_association
# - (via module) azurerm_linux_virtual_machine, azurerm_network_interface, azurerm_public_ip (optional), and any other resources defined in the VM module
#
# Data sources (not created, but required):
# - azurerm_resource_group
# - azurerm_virtual_network
# - azurerm_subnet
#
# -------------------------------------------------------------------------------
# Ensure all variables are set in variables.tf or via tfvars files.
# Review README.md for full onboarding and security notes.
# ===============================================================================

# --- terraform and provider blocks ...

# --- Look up the pre-existing Resource Group (must be created by onboarding script) ---
data "azurerm_resource_group" "main" {
  name = var.dev_cicd_resource_group_name
}

# --- Look up the pre-existing Spoke VNet and its subnet ---
data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.dev_vnet_name
  resource_group_name = var.dev_vnet_resource_group
}

data "azurerm_subnet" "runner_subnet" {
  name                 = var.dev_runner_subnet_name
  virtual_network_name = data.azurerm_virtual_network.spoke_vnet.name
  resource_group_name  = data.azurerm_virtual_network.spoke_vnet.resource_group_name
}

# --- Create a Network Security Group (NSG) for the runner ---
resource "azurerm_network_security_group" "runner_nsg" {
  name                = "nsg-${var.dev_runner_vm_name}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.common_tags
  
  security_rule {
    name                       = "AllowSSHFromMyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.dev_my_home_ip_address}/32"
    destination_address_prefix = "*"
  }
}

# --- Associate the NSG with the runner's subnet ---
resource "azurerm_subnet_network_security_group_association" "runner_nsg_assoc" {
  subnet_id                 = data.azurerm_subnet.runner_subnet.id
  network_security_group_id = azurerm_network_security_group.runner_nsg.id
}

# --- Deploy the Self-Hosted Runner VM using your existing module ---
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