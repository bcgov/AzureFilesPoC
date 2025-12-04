# --- terraform/environments/cicd/variables.tf ---

variable "environment" {
  type        = string
  description = "The target environment (dev, cicd, prod, test)."
  default     = "cicd"
}

variable "azure_location" {
  type        = string
  description = "The Azure region for deploying resources."
}

variable "azure_subscription_id" {
  type        = string
  description = "The Azure subscription ID for resource deployment."
}

# --- Shared Networking Variables ---
variable "vnet_name" {
  type        = string
  description = "The name of the existing Spoke VNet where the runner will be placed."
}

variable "vnet_resource_group" {
  type        = string
  description = "The name of the resource group containing the Spoke VNet."
}

# --- CICD-Specific Variables ---
variable "cicd_resource_group_name" {
  type        = string
  description = "The name of the resource group dedicated to the CI/CD infrastructure."
}

variable "runner_subnet_name" {
  type        = string
  description = "The name of the subnet within the Spoke VNet dedicated to the GitHub Actions runners."
}

variable "runner_vm_name" {
  type        = string
  description = "The name for the self-hosted runner virtual machine."
  default     = "gh-runner-01"
}

variable "my_home_ip_address" {
  type        = string
  description = "Your home/office public IP address for secure SSH access to the runner."
  sensitive   = true
}

variable "runner_network_security_group" {
  type        = string
  description = "The name of the Network Security Group for the runner subnet."
  default       = "nsgrunners"
}

variable "bastion_network_security_group" {
  description = "The name of the Network Security Group to associate with the Bastion subnet."
  type        = string
  default     = ""
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

variable "service_principal_id" {
  type        = string
  description = "Service principal ID for the environment."
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Address space for the VNet."
}

variable "vnet_dns_servers" {
  type        = list(string)
  description = "DNS servers for the VNet."
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers for the environment."
}

variable "runner_vnet_address_space" {
  description = "Address space for the runner subnet (list, e.g., ['10.46.73.16/28']). Use the first element for subnet creation."
  type        = list(string)
}

variable "runner_vm_ip_address" {
  type        = string
  description = "IP address for the runner VM."
  default     = null
}

variable "file_share_name" {
  type        = string
  description = "Name of the Azure File Share for the environment."
  default     = null
}

variable "file_share_quota_gb" {
  type        = number
  description = "Quota (in GB) for the file share."
  default     = null
}

variable "network_security_group" {
  type        = string
  description = "Name of the network security group for the environment."
  default     = null
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet for storage peering."
  default     = null
}

variable "subnet_address_prefixes" {
  type        = list(string)
  description = "Address prefixes for the storage peering subnet."
  default     = null
}

variable "vnet_id" {
  description = "The resource ID of the virtual network."
  type        = string
}

variable "resource_id" {
  description = "The resource ID for a specific resource (please update description as needed)."
  type        = string
}

variable "resource_group" {
  description = "The resource group for the environment (alternate to vnet_resource_group)."
  type        = string
}

variable "storage_account_name" {
  description = "The name of the storage account for the environment."
  type        = string
}

variable "bastion_name" {
  description = "The name for the Bastion host."
  type        = string
}

variable "bastion_public_ip_name" {
  description = "The name for the Bastion public IP resource."
  type        = string
}

variable "bastion_address_prefix" {
  description = "The address prefix for the AzureBastionSubnet (must be a /27 or larger)."
  type        = list(string)
}

variable "tfstate_container" {
  type        = string
  description = "The name of the container for Terraform state storage."
}

variable "tfstate_rg" {
  type        = string
  description = "The resource group for the Terraform state storage account."
}

variable "tfstate_sa" {
  type        = string
  description = "The storage account for Terraform state."
}

variable "vng_name" {
  type        = string
  description = "The name of the Virtual Network Gateway."
}

variable "vng_public_ip_name" {
  type        = string
  description = "The name of the public IP for the Virtual Network Gateway."
}

variable "vng_sku" {
  type        = string
  description = "The SKU for the Virtual Network Gateway."
}

variable "vng_type" {
  type        = string
  description = "The type of the Virtual Network Gateway."
}

variable "vng_vpn_type" {
  type        = string
  description = "The VPN type for the Virtual Network Gateway."
}

variable "gateway_subnet_address_prefix" {
  type        = list(string)
  description = "Address prefix for the GatewaySubnet."
}

variable "bastion_subnet_name" {
  type        = string
  description = "The name of the subnet for Azure Bastion."
}

variable "my_github_actions_spn_object_id" {
  type        = string
  description = "The object ID of the GitHub Actions service principal."
}

variable "runner_vm_admin_username" {
  type        = string
  description = "The admin username for the runner VM."
}

variable "gateway_subnet_name" {
  type        = string
  description = "The name of the GatewaySubnet."
}

variable "runner_vm_size" {
  type        = string
  description = "The size (SKU) of the self-hosted runner virtual machine. Recommended: Standard_DS2_v2 or Standard_B2ms."
  default     = "Standard_D2s_v4"
}

variable "storage_network_security_group" {
  type        = string
  description = "The name of the NSG for the storage subnet."
}

variable "storage_subnet_name" {
  type        = string
  description = "The name of the storage subnet."
}

variable "storage_subnet_address_prefix" {
  type        = list(string)
  description = "The address prefix for the storage subnet."
}