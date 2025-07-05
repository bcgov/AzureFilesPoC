variable "storage_account_name" {
  description = "The globally unique name for the storage account."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the storage account will be created."
  type        = string
}

variable "location" {
  description = "The Azure region for the storage account."
  type        = string
}

variable "azure_location" {
  description = "The Azure region to deploy resources into (for compatibility with parent modules)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the resource."
  type        = map(string)
  default     = {}
}

variable "allowed_ip_rules" {
  type        = list(string)
  description = "A list of public IP CIDR ranges to allow through the firewall. For the GitHub runner."
  default     = []
}

variable "service_principal_id" {
  description = "The object ID of the service principal for role assignments."
  type        = string
}