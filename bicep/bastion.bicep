
// Bastion Host (modular, parameterized)
@description('Location for all resources')
param location string

@description('Name of the Bastion Host')
param bastionHostName string = 'bastion-host'

@description('Resource ID of the AzureBastionSubnet')
param subnetId string

@description('Resource ID of the Public IP for Bastion')
param publicIpId string

@description('Bastion SKU (e.g., Basic, Standard, Developer)')
param skuName string = 'Basic'

resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}

output bastionHostId string = bastionHost.id
