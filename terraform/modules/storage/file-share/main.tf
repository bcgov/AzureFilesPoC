# terraform/modules/storage/file-share/main.tf

# This block is a best practice for modules to declare their provider requirements.
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}

# --------------------------------------------------------------------------------
# NOTE: Role, RBAC, and ACL Requirements for File Share
#
# - The service principal or user creating/managing the file share must have:
#   * Azure RBAC: "Storage File Data SMB Share Contributor" (or higher) assigned at the STORAGE ACCOUNT LEVEL (recommended by Microsoft).
#   * ACLs: If granular access is required, ensure NTFS ACLs are set on the file share after creation.
# - RBAC controls management plane (create/delete/configure) and grants mount/access rights.
# - ACLs (NTFS/Windows permissions) control data plane (read/write/list within the share).
# - Both RBAC and ACLs are required for full access:
#     - RBAC allows mounting and basic access to the share.
#     - ACLs enforce per-file and per-folder permissions (preserved if migrated with tools like robocopy/AzCopy).
# - To use ACLs, set enabledOnboardedWindowsACL = true on the file share and enable Azure AD authentication on the storage account.
# - Assign RBAC roles to Entra (Azure AD) users/groups at the storage account level and set NTFS ACLs for granular access control.
# --------------------------------------------------------------------------------
resource "azurerm_storage_share" "main" {
  name = var.file_share_name
  # FIX: Changed to use the storage account's resource ID to resolve the deprecation warning.
  storage_account_id = var.storage_account_id
  quota              = var.quota_gb

  # Corresponds to properties.enabledProtocols in an Azure export
  enabled_protocol = var.enabled_protocol

  # Corresponds to properties.accessTier in an Azure export
  # Common values are "Hot", "Cool", "TransactionOptimized", "Premium"
  access_tier = var.access_tier

  # Corresponds to the metadata property
  metadata = var.metadata

  # Defines file and folder-level permissions
  dynamic "acl" {
    for_each = var.acls
    content {
      id = acl.value.id
      access_policy {
        permissions = acl.value.permissions
        start       = acl.value.start
        expiry      = acl.value.expiry
      }
    }
  }
}

#==================================================================================
# Assign least-privilege role to the file share resource
#==================================================================================
resource "azurerm_role_assignment" "file_share_contributor" {
  scope                = azurerm_storage_share.main.id
  role_definition_name = "Storage File Data SMB Share Contributor" # Adjust if a more restrictive or custom role is appropriate
  principal_id         = var.service_principal_id
}