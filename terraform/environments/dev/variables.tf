# --- terraform/environments/dev/variables.tf ---
#
# This file defines the "contract" or inputs required to deploy the 'dev' environment.
# The variable names align with the project-wide convention.

variable "storage_account_name" {
  description = "The name of the storage account to create. Must be globally unique."
  type        = string
}

variable "resource_group" {
  description = "The name of the resource group in which to create resources."
  type        = string
}

variable "azure_location" {
  description = "The Azure region to deploy resources into."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
}

variable "service_principal_id" {
  description = "The object ID of the service principal used for role assignments."
  type        = string
}

variable "vnet_name" {
  description = "The name of the existing virtual network to use."
  type        = string
}

variable "vnet_resource_group" {
  description = "The resource group of the existing virtual network."
  type        = string
}

variable "storage_network_security_group" {
  description = "The name of the NSG for the storage subnet."
  type        = string
}

variable "storage_subnet_address_prefix" {
  description = "The address prefix(es) for the storage subnet."
  type        = list(string)
}

variable "storage_subnet_name" {
  description = "The name of the storage subnet."
  type        = string
}

variable "file_share_name" {
  description = "The name of the Azure file share to create."
  type        = string
}

# Optional variables for commented-out modules (add as needed for future use)
variable "private_dns_zone_name" {
  description = "The name of the private DNS zone."
  type        = string
  default     = null
}

variable "private_dns_vnet_link_name" {
  description = "The name of the private DNS VNet link."
  type        = string
  default     = null
}

variable "blob_container_name" {
  description = "The name of the blob container to create (optional)."
  type        = string
  default     = null
}

variable "storage_management_policy" {
  description = "The storage management policy JSON (optional)."
  type        = any
  default     = null
}

variable "file_sync_service_name" {
  description = "The name of the Azure File Sync service (optional)."
  type        = string
  default     = null
}

variable "log_analytics_workspace_name" {
  description = "The name of the Log Analytics workspace (optional)."
  type        = string
  default     = null
}

variable "automation_account_name" {
  description = "The name of the Automation Account (optional)."
  type        = string
  default     = null
}

variable "bastion_network_security_group" {
  description = "The name of the NSG for the Bastion subnet (optional)."
  type        = string
  default     = null
}

variable "bastion_address_prefix" {
  description = "The address prefix(es) for the Bastion subnet (optional)."
  type        = list(string)
  default     = []
}

variable "bastion_subnet_name" {
  description = "The name of the Bastion subnet (optional)."
  type        = string
  default     = null
}

variable "bastion_name" {
  description = "The name of the Bastion host (optional)."
  type        = string
  default     = null
}

variable "bastion_public_ip_name" {
  description = "The name of the public IP for Bastion (optional)."
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "The address space for the dev VNet."
  type        = list(string)
  default     = []
}

variable "vnet_dns_servers" {
  description = "The DNS servers for the dev VNet."
  type        = list(string)
  default     = []
}

variable "vnet_id" {
  description = "The resource ID of the dev VNet."
  type        = string
  default     = ""
}

variable "resource_id" {
  description = "The resource ID of the dev resource group."
  type        = string
  default     = ""
}

variable "file_share_quota_gb" {
  description = "The maximum size of the file share in GB for the dev environment."
  type        = number
  default     = 100
}

variable "network_security_group" {
  description = "The name of the Network Security Group for the dev environment."
  type        = string
  default     = ""
}

variable "dns_servers" {
  description = "The DNS servers for the dev environment."
  type        = list(string)
  default     = []
}

variable "allowed_ip_rules" {
  description = "A list of public IP CIDR ranges to allow through the storage account firewall, passed from the CI/CD pipeline."
  type        = list(string)
  default     = []
}

variable "runner_vm_size" {
  description = "The size of the GitHub Actions runner VM."
  type        = string
  default     = "Standard_D2s_v4"
}

variable "runner_vm_name" {
  description = "The name of the GitHub Actions runner VM."
  type        = string
}

variable "runner_vm_ip_address" {
  description = "The IP address of the GitHub Actions runner VM."
  type        = string
}

variable "runner_vm_admin_username" {
  description = "The admin username for the GitHub Actions runner VM."
  type        = string
}

variable "cicd_resource_group_name" {
  description = "The name of the CI/CD resource group."
  type        = string
}

variable "runner_network_security_group" {
  description = "The name of the runner network security group."
  type        = string
}

variable "my_github_actions_spn_object_id" {
  description = "The object ID of the GitHub Actions service principal."
  type        = string
}

variable "my_home_ip_address" {
  description = "The home IP address for access control."
  type        = string
}

variable "admin_ssh_key_public" {
  description = "The public SSH key for VM admin access."
  type        = string
}