# In /terraform/modules/networking/private-endpoint/variables.tf

variable "private_endpoint_name" {
  description = "The name of the Private Endpoint."
  type        = string
}

variable "location" {
  description = "The Azure region for the Private Endpoint."
  type        = string
}

variable "resource_group" {
  description = "The resource group for the Private Endpoint."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "The subnet ID for the Private Endpoint."
  type        = string
}

variable "private_service_connection_name" {
  description = "The name of the private service connection."
  type        = string
}

variable "private_connection_resource_id" {
  description = "The resource ID of the service to connect to (e.g., the storage account ID)."
  type        = string
}

variable "subresource_names" {
  description = "A list of sub-resource names for the connection (e.g., ['file'] for Azure Files)."
  type        = list(string)
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access to the private endpoint."
  type        = string
}