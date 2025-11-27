variable "automation_account_name" {
  description = "The name of the Automation Account."
  type        = string
}

variable "resource_group_name" {
  description = "The resource group for the Automation Account."
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
