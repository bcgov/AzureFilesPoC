variable "route_table_name" {
  description = "The name of the Route Table."
  type        = string
}

variable "resource_group_name" {
  description = "The resource group for the Route Table."
  type        = string
}

variable "location" {
  description = "The Azure region."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply."
  type        = map(string)
  default     = {}
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access."
  type        = string
}
