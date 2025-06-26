# In /terraform/modules/core/resource-group/main.tf

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
