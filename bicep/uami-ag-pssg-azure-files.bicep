// Bicep template for User-Assigned Managed Identity
// Used for passwordless authentication to Storage, Key Vault, and AI Foundry

param uamiName string
param location string = resourceGroup().location
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

output uamiId string = uami.id
output uamiName string = uami.name
output uamiPrincipalId string = uami.properties.principalId
output uamiClientId string = uami.properties.clientId
