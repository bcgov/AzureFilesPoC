// Bicep template for storage account: stagpssgazurepocdev01
// Edit parameters as needed for your environment
//
// IMPORTANT: To upload/download files from your local machine:
// 1. Add your public IP address to the ipRules array below
// 2. Use CIDR notation (e.g., '203.0.113.0/24' for range or '203.0.113.45' for single IP)
// 3. After deployment, generate SAS token for blob container access:
//    az storage container generate-sas --account-name stagpssgazurepocdev01 \
//      --name <container-name> --permissions acdlrw \
//      --expiry 2025-12-31T23:59:59Z --https-only
//
// Current IP allowlist:
// - 142.30.100.140 (existing IP)

param storageAccountName string = 'stagpssgazurepocdev01'
param location string = resourceGroup().location
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: true
    defaultToOAuthAuthentication: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: '142.28.0.0/16'
          action: 'Allow'
        }
        {
          value: '142.29.0.0/16'
          action: 'Allow'
        }
        {
          value: '142.30.0.0/16'
          action: 'Allow'
        }
        {
          value: '142.31.0.0/16'
          action: 'Allow'
        }
        {
          value: '142.32.0.0/16'
          action: 'Allow'
        }
      ]
      virtualNetworkRules: []
      resourceAccessRules: [
        {
          tenantId: '6fdb5200-3d0d-4a8a-b036-d3685e359adc'
          resourceId: '/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/providers/Microsoft.Security/datascanners/StorageDataScanner'
        }
      ]
    }
  }
}
