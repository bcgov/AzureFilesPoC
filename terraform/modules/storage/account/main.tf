# In /terraform/modules/storage/account/main.tf

resource "azurerm_storage_account" "main" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  large_file_share_enabled          = true
  access_tier                       = "Hot"
  min_tls_version                   = "TLS1_2"
  allow_nested_items_to_be_public = false # This is for blob public access, good to keep false

  # --- CONFIGURATION FOR THIS TEST ---
  # Keep public network access disabled, as that's your desired end state.
  public_network_access_enabled = false 

  network_rules {
    # If publicNetworkAccess is false, default_action is implicitly Deny.
    # Explicitly setting it doesn't hurt.
    default_action = "Deny"
    
    # This is the key setting for this test.
    # It allows Azure services on the trusted list to access this storage account.
    # to allow github to be allowed to connect via CI/CD to azure for terraform
    bypass         = ["AzureServices"]
    
    # We are not using specific IP rules for this test.
    ip_rules       = [] 
    
    # We are not using VNet rules yet.
    virtual_network_subnet_ids = []
  }
}

#==================================================================================
# Assign roles to the storage account for data operations
#==================================================================================

# Assign Storage Blob Data Contributor
resource "azurerm_role_assignment" "blob_data_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.service_principal_id
}

# Assign Storage File Data SMB Share Contributor
resource "azurerm_role_assignment" "file_data_smb_share_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data SMB Share Contributor"
  principal_id         = var.service_principal_id
}

# Assign Storage File Data Privileged Contributor
resource "azurerm_role_assignment" "file_data_privileged_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage File Data Privileged Contributor"
  principal_id         = var.service_principal_id
}

# Assign Storage Blob Data Owner
resource "azurerm_role_assignment" "blob_data_owner" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = var.service_principal_id
}

