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
variable "admin_ssh_key_public" {
  type        = string
  description = "The public SSH key for VM admin access (from GitHub secret ADMIN_SSH_KEY_PUBLIC)."
}

variable "common_tags" {
  type        = map(string)
  description = "A map of common tags to apply to all resources."
  default     = {}
}

variable "dev_service_principal_id" {
  type        = string
  description = "Service principal ID for the dev environment."
}

variable "dev_vnet_address_space" {
  type        = list(string)
  description = "Address space for the dev VNet."
}

variable "dev_vnet_dns_servers" {
  type        = list(string)
  description = "DNS servers for the dev VNet."
}

variable "dev_dns_servers" {
  type        = list(string)
  description = "DNS servers for the dev environment."
}

variable "dev_runner_vnet_address_space" {
  type        = list(string)
  description = "Address space for the runner subnet."
}

variable "dev_runner_vm_ip_address" {
  type        = string
  description = "IP address for the runner VM."
  default     = null
}

variable "dev_file_share_name" {
  type        = string
  description = "Name of the Azure File Share for the dev environment."
  default     = null
}

variable "dev_file_share_quota_gb" {
  type        = number
  description = "Quota (in GB) for the dev file share."
  default     = null
}

variable "dev_network_security_group" {
  type        = string
  description = "Name of the network security group for the dev environment."
  default     = null
}

variable "dev_subnet_name" {
  type        = string
  description = "Name of the subnet for storage peering."
  default     = null
}

variable "dev_subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the storage peering subnet."
  default     = null
}

variable "dev_vnet_id" {
  description = "The resource ID of the development virtual network."
  type        = string
}

variable "dev_resource_id" {
  description = "The resource ID for a specific dev resource (please update description as needed)."
  type        = string
}

variable "dev_vnet_dnsServers" {
  description = "DNS servers for the dev VNet (alternate spelling, see dev_vnet_dns_servers)."
  type        = list(string)
}

variable "dev_resource_group" {
  description = "The resource group for the dev environment (alternate to dev_vnet_resource_group)."
  type        = string
}

variable "dev_storage_account_name" {
  description = "The name of the storage account for the dev environment."
  type        = string
}

variable "dev_bastion_name" {
  description = "The name for the Bastion host."
  type        = string
}

variable "dev_bastion_public_ip_name" {
  description = "The name for the Bastion public IP resource."
  type        = string
}

variable "dev_bastion_address_prefix" {
  description = "The address prefix for the AzureBastionSubnet (must be a /27 or larger)."
  type        = list(string)
}
