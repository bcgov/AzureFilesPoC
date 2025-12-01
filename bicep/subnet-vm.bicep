// Bicep: subnet-vm.bicep
// Creates a VM subnet in an existing VNet

param vnetName string
param subnetName string = 'snet-ag-pssg-azure-files-vm'
param addressPrefix string = '10.0.1.0/24'
param resourceGroupName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: vnetName
  scope: resourceGroup(resourceGroupName)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: addressPrefix
  }
}

output subnetId string = subnet.id
