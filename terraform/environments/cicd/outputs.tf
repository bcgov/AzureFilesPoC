# --- terraform/environments/cicd/outputs.tf ---

# output "runner_vm_id" {
#   description = "The full Azure Resource ID of the self-hosted runner VM."
#   value       = module.self_hosted_runner_vm.vm_id
# }

# output "runner_vm_private_ip_address" {
#   description = "The private IP address of the self-hosted runner VM."
#   value       = module.self_hosted_runner_vm.private_ip_address
# }

# output "ssh_command" {
#   description = "The command to use to SSH into the runner VM for manual setup."
#   value       = "ssh ${module.self_hosted_runner_vm.admin_username}@${module.self_hosted_runner_vm.private_ip_address}"
#   # NOTE: This command assumes you are on a network with connectivity to the VNet (e.g., VPN or ExpressRoute).
#   # For initial setup from the internet, you would need to assign a public IP to the VM's NIC.
# }