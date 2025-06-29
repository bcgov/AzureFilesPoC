# --- terraform/environments/cicd/variables.tf ---

variable "azure_location" {
  type        = string
  description = "The Azure region for deploying resources."
}

# --- Shared Networking Variables (using consistent 'dev_' prefix) ---
variable "dev_vnet_name" {
  type        = string
  description = "The name of the existing Spoke VNet where the runner will be placed."
}

variable "dev_vnet_resource_group" {
  type        = string
  description = "The name of the resource group containing the Spoke VNet."
}

# --- CICD-Specific Variables (now with 'dev_' prefix) ---
variable "dev_cicd_resource_group_name" {
  type        = string
  description = "The name of the resource group dedicated to the dev CI/CD infrastructure."
}

variable "dev_runner_subnet_name" {
  type        = string
  description = "The name of the subnet within the Spoke VNet dedicated to the dev GitHub Actions runners."
}

variable "dev_runner_vm_name" {
  type        = string
  description = "The name for the dev self-hosted runner virtual machine."
  default     = "gh-runner-dev-01"
}

variable "dev_my_home_ip_address" {
  type        = string
  description = "Your home/office public IP address for secure SSH access to the dev runner."
  sensitive   = true
}

variable "dev_runner_network_security_group" {
  type        = string
  description = "The name of the Network Security Group for the runner subnet."
  default       = "nsgrunners"
}

# --- Common Variables ---
variable "admin_ssh_key_public_path" {
  type        = string
  description = "The local file path to the public SSH key for the VM admin user."
  default     = "~/.ssh/id_rsa.pub"
}

variable "common_tags" {
  type        = map(string)
  description = "A map of common tags to apply to all resources."
  default     = {}
}