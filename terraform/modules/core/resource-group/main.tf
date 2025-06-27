# In /terraform/modules/core/resource-group/main.tf
# REQUIREMENTS: 
# 1. The service principal running this automation MUST have either the "User Access Administrator" or "Owner" role assigned at the SUBSCRIPTION level (or higher).
#    - Without one of these roles, the service principal will NOT be able to assign roles to the resource group during creation.
#    - Custom roles CANNOT grant this permission; only the built-in roles "User Access Administrator" or "Owner" provide the required access (Microsoft.Authorization/roleAssignments/write).
# 2. These permissions are required for any automation that creates resource groups and assigns roles within them.
# 3. If you do not have these permissions, request them from your Azure administrator before running this module.
#
# Reference: https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal
#
#==================================================================================
#1. Create a Resource Group and Assign Roles for Storage Account and Data Operations
#==================================================================================
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}


#==================================================================================
#2. assign roles to the resource group for storage account and data operations
#==================================================================================

#===================================================================================
#2a. Assign custom role for role assignment management (data/control plane automation)
#===================================================================================
resource "azurerm_role_assignment" "role_assignment_writer" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "ag-pssg-azure-files-poc-dev-role-assignment-writer"
  principal_id         = var.service_principal_id
}

# Note: You must define the variables for the principal IDs in variables.tf and provide them when using this module.
