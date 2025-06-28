# --- terraform/environments/cicd/main.tf ---
# This configuration bootstraps the dev environment's self-hosted runner.

# ... terraform and provider blocks ...

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

# --- Create a dedicated Resource Group for the Dev Runner ---
resource "azurerm_resource_group" "main" {
  name     = var.dev_cicd_resource_group_name
  location = var.azure_location
  tags     = var.common_tags
}

# --- Create a Network Security Group (NSG) for the runner ---
resource "azurerm_network_security_group" "runner_nsg" {
  name                = "nsg-${var.dev_runner_vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
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
  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  subnet_id             = data.azurerm_subnet.runner_subnet.id
  admin_ssh_key_public  = file(var.admin_ssh_key_public_path)
  tags                  = var.common_tags
  # ... and any other variables your vm module needs ...
  
  depends_on = [
    azurerm_subnet_network_security_group_association.runner_nsg_assoc
  ]
}