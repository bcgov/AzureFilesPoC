# --- terraform/modules/vm/outputs.tf ---

output "vm_id" {
  description = "The ID of the created virtual machine."
  value       = azurerm_linux_virtual_machine.main.id
}

output "private_ip_address" {
  description = "The primary private IP address of the virtual machine."
  value       = azurerm_network_interface.main.private_ip_address
}

output "vm_principal_id" {
  description = "The Principal ID of the System Assigned Managed Identity for the VM (if enabled)."
  value       = azurerm_linux_virtual_machine.main.identity[0].principal_id
}