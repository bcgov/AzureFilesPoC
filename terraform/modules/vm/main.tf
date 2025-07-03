# --- terraform/modules/vm/main.tf ---
#
# This module is designed and optimized for secure, reliable hosting of self-hosted GitHub Actions runners on Azure.
# It follows best practices for BC Gov and GitHub runner deployments, including:
#   - Secure SSH key authentication (no password login)
#   - No public IP by default (private VNet/subnet only)
#   - Customizable VM size, image, and tags
#   - Cloud-init (custom_data) support for automated runner setup
#
# Resources created by this module:
#
# 1. azurerm_network_interface.main
#    - Creates a network interface (NIC) for the VM, attaches it to the specified subnet.
#    - Provides private IP connectivity for the runner VM.
#
# 2. azurerm_linux_virtual_machine.main
#    - Provisions the Linux VM for the GitHub runner.
#    - Attaches the NIC, sets OS image, VM size, and tags.
#    - Configures SSH key authentication and disables password login for security.
#    - Runs a cloud-init (custom_data) script to install and register the GitHub Actions runner agent on first boot.
#    - No public IP is assigned by default (private runner).
#
# All variables (VM name, size, image, subnet, tags, etc.) are passed in for maximum flexibility and reusability.
#
# Usage: See the parent environment's main.tf for example module usage and required variables.

# A VM requires a Network Interface (NIC) to connect to the VNet/subnet.
# Public IP resource is not created, as public IPs are disallowed by policy.
# resource "azurerm_public_ip" "main" {
#   count               = var.assign_public_ip ? 1 : 0
#   name                = "${var.vm_name}-pip"
#   location            = var.azure_location
#   resource_group_name = var.resource_group_name
#   allocation_method   = var.public_ip_allocation_method
#   sku                 = var.public_ip_sku
#   tags                = var.tags
# }

resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.main[0].id : null
  }
}

# This is the main Virtual Machine resource.
resource "azurerm_linux_virtual_machine" "main" {
  name                  = var.vm_name
  resource_group_name   = var.resource_group_name
  location              = var.azure_location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.main.id]
  tags                  = var.tags

  # This section configures the OS disk.
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # This section points to the OS image to use from the Azure Marketplace.
  source_image_reference {
    publisher = var.source_image_reference.publisher
    offer     = var.source_image_reference.offer
    sku       = var.source_image_reference.sku
    version   = var.source_image_reference.version
  }

  # This configures authentication using the provided SSH public key.
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_key_public
  }
  
  # This disables password authentication, which is a security best practice.
  disable_password_authentication = true

  # This runs a setup script on the first boot.
  # It must be base64-encoded.
  custom_data = var.custom_data_script

  # Assign a system-assigned managed identity to the VM for secure Azure resource access.
  identity {
    type = "SystemAssigned"
  }
}