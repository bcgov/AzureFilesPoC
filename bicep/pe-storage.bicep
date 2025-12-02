// bicep/pe-storage.bicep
// Private Endpoint for Storage Account
@description('Name of the private endpoint')
param peName string

@description('Azure region for the private endpoint (should match VNet region)')
param location string

@description('Resource ID of the subnet for private endpoint')
param subnetId string

@description('Resource ID of the Storage Account')
param storageAccountId string

@allowed([
  'blob'
  'file'
  'queue'
  'table'
])
@description('Storage subresource to expose via Private Endpoint')
param storageSubresource string = 'blob'

// Private Endpoint
resource peStorage 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: peName
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccountId
          // IMPORTANT: match the subresource you need (blob/file/queue/table)
          groupIds: [
            storageSubresource
          ]
        }
      }
    ]
  }
}

// Note: DNS zone groups will be managed centrally
// Private DNS zones are created in connectivity subscription and linked to VNets
