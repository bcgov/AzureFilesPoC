# In /terraform/modules/storage/account/variables.tf

variable "storage_account_name" {
  description = "The name of the Azure Storage Account."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group in which to create the storage account."
  type        = string
}

variable "azure_location" {
  description = "The Azure region where the storage account will be created."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the storage account."
  type        = map(string)
  default     = {}
}

variable "service_principal_id" {
  description = "(Optional) The object ID of a service principal for role assignments."
  type        = string
  default     = null
}

variable "runner_subnet_id" {
  description = "(Optional) The resource ID of the GitHub runner subnet. Currently unused."
  type        = string
  default     = null
}

# --- NEW VARIABLE ADDED ---
variable "storage_subnet_id" {
  description = "The ID of the subnet where the Private Endpoint for the storage account will be placed."
  type        = string
}