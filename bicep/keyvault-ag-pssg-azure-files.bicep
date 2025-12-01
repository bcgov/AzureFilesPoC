// Bicep template for Azure Key Vault
// Deploys Key Vault with network restrictions and RBAC-based access

param keyVaultName string
param location string = resourceGroup().location
param tenantId string = subscription().tenantId
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    enableRbacAuthorization: true // Use RBAC instead of access policies
    publicNetworkAccess: 'Disabled' // BC Gov policy requirement
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [] // IP rules not applicable when publicNetworkAccess is Disabled
      virtualNetworkRules: []
    }
  }
}

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
