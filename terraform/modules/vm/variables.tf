# --- terraform/modules/vm/variables.tf ---

variable "vm_name" {
  type        = string
  description = "The name of the Linux virtual machine."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the VM."
}

variable "location" {
  type        = string
  description = "The Azure region where the VM will be created."
}

variable "subnet_id" {
  type        = string
  description = "The ID of the subnet to which the VM's network interface will connect."
}

variable "vm_size" {
  type        = string
  description = "The size (SKU) of the virtual machine."
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the VM."
  default     = "azureadmin"
}

variable "admin_ssh_key_public" {
  type        = string
  description = "The public portion of the SSH key for authenticating to the VM."
  sensitive   = true
}

variable "custom_data_script" {
  type        = string
  description = "A base64-encoded cloud-init script to run on the VM's first boot for setup."
  default     = null
}

variable "source_image_reference" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "The marketplace image to use for the VM's OS."
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to all created resources."
  default     = {}
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP address to the VM's NIC."
  type        = bool
  default     = false
}

variable "public_ip_sku" {
  description = "The SKU for the public IP address (Basic or Standard)."
  type        = string
  default     = "Standard"
}

variable "public_ip_allocation_method" {
  description = "The allocation method for the public IP address (Static or Dynamic)."
  type        = string
  default     = "Static"
}