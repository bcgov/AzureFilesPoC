// bicep/pe-foundry.bicep
// Private Endpoint for Azure AI Foundry (AML Workspace)
@description('Name of the private endpoint')
param peName string

@description('Azure region for the private endpoint (should match VNet region)')
param location string

@description('Resource ID of the subnet for private endpoint')
param subnetId string

@description('Resource ID of the Azure AI Foundry (AML) workspace')
param foundryId string

// Private Endpoint for AML workspace
resource peFoundry 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'foundry-connection'
        properties: {
          privateLinkServiceId: foundryId
          groupIds: [
            'amlworkspace' // current groupId for AML Workspaces
          ]
        }
      }
    ]
  }
}

// Note: DNS zone groups will be managed centrally
// Private DNS zones are created in connectivity subscription and linked to VNets
