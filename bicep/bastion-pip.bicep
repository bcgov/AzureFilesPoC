
// Bastion Public IP (modular, parameterized)
@description('Location for the Public IP')
param location string

@description('Name of the Public IP resource')
param publicIpName string = 'bastion-pip'

@description('SKU for the Public IP (Standard recommended)')
param publicIpSku string = 'Standard'

resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

output publicIpId string = bastionPip.id
