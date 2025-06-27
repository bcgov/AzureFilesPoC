# Azure File Sync resources with least-privilege RBAC

resource "azurerm_storage_sync_service" "main" {
  name                = var.sync_service_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "sync_service_contributor" {
  scope                = azurerm_storage_sync_service.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.service_principal_id
}

# Add additional resources (sync group, cloud endpoint) as needed
