// bicep/openai-ag-pssg-azure-files.bicep
// Azure OpenAI resource with private endpoint support
// Required for deploying and consuming AI models via private connectivity

@description('Name of the Azure OpenAI resource')
param openAIName string

@description('Azure region for the OpenAI resource')
param location string

@description('SKU for the OpenAI resource')
@allowed([
  'S0'
])
param sku string = 'S0'

@description('Whether to disable public network access')
param publicNetworkAccess string = 'Disabled'

@description('Tags for the resource')
param tags object = {}

// Azure OpenAI Cognitive Services Account
resource openAI 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: openAIName
  location: location
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  properties: {
    customSubDomainName: openAIName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  tags: tags
}

// Output the resource ID for private endpoint creation
output openAIId string = openAI.id
output openAIEndpoint string = openAI.properties.endpoint
output openAIName string = openAI.name
