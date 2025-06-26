# In /terraform/modules/core/resource-group/main.tf

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Candidate role assignments for storage account and data operations
# Assign Storage Account Contributor to a principal (e.g., a service principal or group)
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = var.service_principal_id
}

# Assign Storage Blob Data Contributor for blob/container operations
resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.service_principal_id
}

# Assign Storage File Data SMB Share Contributor for Azure Files operations
resource "azurerm_role_assignment" "file_data_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.service_principal_id
}

# Assign custom role for role assignment management (data/control plane automation)
resource "azurerm_role_assignment" "role_assignment_writer" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "ag-pssg-azure-files-poc-dev-role-assignment-writer"
  principal_id         = var.service_principal_id
}

# Note: You must define the variables for the principal IDs in variables.tf and provide them when using this module.
