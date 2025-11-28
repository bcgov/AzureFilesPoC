// Bicep template for storage account: stagpssgazurepocdev01
// Edit parameters as needed for your environment

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
          value: '142.30.100.140'
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
