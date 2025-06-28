# --- terraform/modules/vm/main.tf ---

# A VM requires a Network Interface (NIC) to connect to the VNet/subnet.
resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

# This is the main Virtual Machine resource.
resource "azurerm_linux_virtual_machine" "main" {
  name                  = var.vm_name
  resource_group_name   = var.resource_group_name
  location              = var.location
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
}