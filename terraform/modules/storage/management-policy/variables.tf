variable "storage_account_id" {
  description = "The ID of the storage account."
  type        = string
}

variable "policy" {
  description = "The management policy JSON."
  type        = any
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access."
  type        = string
}
