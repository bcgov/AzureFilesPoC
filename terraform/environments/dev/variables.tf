# --- terraform/environments/dev/variables.tf ---
#
# This file defines the "contract" or inputs required to deploy the 'dev' environment.
# The variable names align with the project-wide convention.

variable "dev_resource_group" {
  description = "The name of the new resource group for PoC services."
  type        = string
}

variable "dev_storage_account_name" {
  description = "The globally unique name for the PoC storage account."
  type        = string
}

variable "dev_vnet_name" {
  description = "The name of the existing VNet to connect to."
  type        = string
}

variable "dev_vnet_resource_group" {
  description = "The name of the resource group where the existing VNet is located."
  type        = string
}

variable "dev_subnet_name" {
  description = "The name of the new subnet for private endpoints."
  type        = string
}

variable "dev_subnet_address_prefixes" {
  description = "A list of CIDR address blocks for the new subnet."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "azure_location" {
  description = "The Azure region for the dev environment. (Matches tfvars)"
  type        = string
}

variable "dev_vnet_address_space" {
  description = "The address space for the dev VNet."
  type        = list(string)
}

variable "dev_vnet_dns_servers" {
  description = "The DNS servers for the dev VNet."
  type        = list(string)
}

variable "dev_vnet_id" {
  description = "The resource ID of the dev VNet."
  type        = string
}

variable "dev_resource_id" {
  description = "The resource ID of the dev resource group."
  type        = string
}

variable "dev_file_share_name" {
  description = "The name of the Azure File Share."
  type        = string
}

variable "dev_file_share_quota_gb" {
  description = "The maximum size of the file share in GB for the dev environment."
  type        = number
  default     = 100
}

variable "dev_network_security_group" {
  description = "The name of the Network Security Group for the dev environment."
  type        = string
}

variable "dev_dns_servers" {
  description = "The DNS servers for the dev environment."
  type        = list(string)
}

variable "dev_resource_group_b" {
  description = "The name of the second resource group to be created by Terraform."
  type        = string
}

variable "allowed_ip_rules" {
  description = "A list of public IP CIDR ranges to allow through the storage account firewall, passed from the CI/CD pipeline."
  type        = list(string)
  default     = []
}

variable "service_principal_id" {
  description = "The object ID of the service principal for role assignments."
  type        = string
}

variable "dev_service_principal_id" {
  description = "The object ID of the service principal for role assignments."
  type        = string
}

variable "dev_file_sync_service_name" {
  description = "The name of the Azure File Sync Service."
  type        = string
}

variable "dev_log_analytics_workspace_name" {
  description = "The name of the Log Analytics Workspace."
  type        = string
}

variable "dev_automation_account_name" {
  description = "The name of the Automation Account."
  type        = string
}

variable "dev_firewall_name" {
  description = "The name of the Azure Firewall."
  type        = string
}

variable "dev_route_table_name" {
  description = "The name of the Route Table."
  type        = string
}

variable "dev_vnet_gateway_name" {
  description = "The name of the Virtual Network Gateway."
  type        = string
}

variable "dev_gateway_type" {
  description = "The type of the gateway (Vpn or ExpressRoute)."
  type        = string
}

variable "dev_vpn_type" {
  description = "The VPN type (RouteBased or PolicyBased)."
  type        = string
}

variable "dev_vnet_gateway_sku" {
  description = "The SKU of the Virtual Network Gateway."
  type        = string
}

variable "dev_vnet_gateway_ip_configurations" {
  description = "A list of IP configuration blocks for the Virtual Network Gateway."
  type        = any
}

variable "dev_blob_container_name" {
  description = "The name of the blob container."
  type        = string
}

variable "dev_storage_management_policy" {
  description = "The management policy JSON for the storage account."
  type        = any
}

variable "dev_private_dns_zone_name" {
  description = "The name of the Private DNS Zone."
  type        = string
}

variable "dev_private_dns_vnet_link_name" {
  description = "The name of the VNet link for the Private DNS Zone."
  type        = string
}

variable "dev_virtual_network_id" {
  description = "The ID of the virtual network to link to the Private DNS Zone."
  type        = string
}