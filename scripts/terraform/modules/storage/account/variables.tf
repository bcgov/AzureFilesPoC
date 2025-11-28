# terraform/modules/storage/account/variables.tf

variable "storage_account_name" {
  description = "The name of the Azure Storage Account."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "azure_location" {
  description = "The Azure region."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign."
  type        = map(string)
  default     = {}
}