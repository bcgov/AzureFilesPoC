// Bicep template for Log Analytics Workspace
// Centralized logging and diagnostics for all Azure resources

param lawName string
param location string = resourceGroup().location
param retentionInDays int = 30
param tags object = {
  account_coding: '105150471019063011500000'
  billing_group: 'd5007d'
  ministry_name: 'AG'
  owner: 'ag-pssg-teams'
  project: 'ag-pssg-azure-files-poc'
}

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output lawId string = law.id
output lawName string = law.name
output lawCustomerId string = law.properties.customerId
