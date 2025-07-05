terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.0"
    }
  }
}

# Create blob container using AzAPI provider
resource "azapi_resource" "blob_container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01"
  name      = var.container_name
  parent_id = "${var.storage_account_id}/blobServices/default"
  
  body = jsonencode({
    properties = {
      publicAccess = var.container_access_type == "private" ? "None" : (
        var.container_access_type == "blob" ? "Blob" : "Container"
      )
      metadata = var.metadata
    }
  })
}