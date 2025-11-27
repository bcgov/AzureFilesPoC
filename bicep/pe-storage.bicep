// Private Endpoint for Storage
resource peStorage 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-storage'
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
          groupIds: [ 'file' ]
        }
      }
    ]
  }
}
