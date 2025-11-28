// Private Endpoint for Key Vault
resource peKeyVault 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-keyvault'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyvault-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: [ 'vault' ]
        }
      }
    ]
  }
}
