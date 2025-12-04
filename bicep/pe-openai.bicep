// bicep/pe-openai.bicep
// Private Endpoint for Azure OpenAI resource
@description('Name of the private endpoint')
param peName string

@description('Azure region for the private endpoint (should match VNet region)')
param location string

@description('Resource ID of the subnet for private endpoint')
param subnetId string

@description('Resource ID of the Azure OpenAI resource')
param openAIId string

// Private Endpoint for Azure OpenAI
resource peOpenAI 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'openai-connection'
        properties: {
          privateLinkServiceId: openAIId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

// Note: DNS zone groups will be managed centrally
// Private DNS zones are created in connectivity subscription and linked to VNets
