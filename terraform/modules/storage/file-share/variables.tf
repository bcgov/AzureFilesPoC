# terraform/modules/storage/file-share/variables.tf

variable "file_share_name" {
  type        = string
  description = "The name of the file share to create."
}

# --- FIX: Changed from 'storage_account_name' to 'storage_account_id' ---
variable "storage_account_id" {
  type        = string
  description = "The resource ID of the existing storage account where the share will be created."
}

variable "quota_gb" {
  type        = number
  description = "The quota of the file share in GiB."
}

variable "enabled_protocol" {
  type        = string
  description = "The protocol to enable on the file share. e.g., 'SMB' or 'NFS'."
  default     = "SMB"
}

variable "access_tier" {
  type        = string
  description = "The access tier of the file share. Can be 'Hot', 'Cool', 'TransactionOptimized', or 'Premium'."
  default     = "Hot"
}

variable "metadata" {
  type        = map(string)
  description = "A map of metadata to assign to the share."
  default     = {}
}

variable "acls" {
  type = list(object({
    id          = string
    permissions = string
    start       = optional(string)
    expiry      = optional(string)
  }))
  description = "A list of Access Control Lists for the file share. See azurerm_storage_share documentation for details."
  default     = [] # Default to no ACLs for simplicity
}

variable "service_principal_id" {
  description = "The object ID of the service principal or user to assign least-privilege access to the file share."
  type        = string
}

variable "enabled_onboarded_windows_acl" {
  type        = bool
  description = "Enable NTFS ACL support for Azure Files. (enabledOnboardedWindowsACL)"
  default     = false
}

variable "root_squash" {
  type        = string
  description = "Root squash setting for NFS shares. Possible values: 'NoRootSquash', 'RootSquash', 'AllSquash'. (rootSquash)"
  default     = null
}

variable "backup_enabled" {
  type        = bool
  description = "Enable Azure Backup for the file share. (backupEnabled)"
  default     = false
}

variable "delete_retention_policy" {
  type = object({
    enabled = bool
    days    = number
  })
  description = "Soft delete retention policy for the file share. (deleteRetentionPolicy)"
  default = {
    enabled = false
    days    = 7
  }
}