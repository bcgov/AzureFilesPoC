// filename: bicep/bastion-nic.bicep
// Bastion NIC (modular, parameterized)
@description('Location for the NIC')
param location string

@description('Name of the NIC resource')
param nicName string = 'bastion-nic'

@description('Resource ID of the AzureBastionSubnet')
param subnetId string

@description('Resource ID of the Public IP for Bastion')
param publicIpId string

resource bastionNic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}

output nicId string = bastionNic.id
