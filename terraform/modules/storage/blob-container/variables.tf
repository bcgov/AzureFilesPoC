variable "container_name" {
  description = "The name of the blob container."
  type        = string
}

variable "storage_account_name" {
  description = "The name of the storage account."
  type        = string
}

variable "container_access_type" {
  description = "The access type of the container (private, blob, container)."
  type        = string
  default     = "private"
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access."
  type        = string
}

variable "metadata" {
  description = "A map of metadata to assign to the blob container."
  type        = map(string)
  default     = {}
}
