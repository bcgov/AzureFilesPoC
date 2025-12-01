// Azure Bastion deployment with Public IP and subnet reference
@description('Location for all resources')
param location string = resourceGroup().location

@description('Name of the Bastion Host')
param bastionName string

@description('Name of the Virtual Network')
param vnetName string

@description('Resource group containing the VNet')
param vnetResourceGroup string

@description('Name of the AzureBastionSubnet')
param subnetName string = 'AzureBastionSubnet'

@description('Name of the Public IP for Bastion')
param publicIpName string

@description('Bastion SKU')
@allowed([
  'Basic'
  'Standard'
])
param skuName string = 'Standard'

// Reference existing VNet in different resource group
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: resourceGroup(vnetResourceGroup)
  name: vnetName
}

// Reference existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: subnetName
}

// Create Public IP for Bastion
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Create Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2023-11-01' = {
  name: bastionName
  location: location
  sku: {
    name: skuName
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnet.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

output bastionHostId string = bastionHost.id
output bastionHostName string = bastionHost.name
output publicIpAddress string = publicIp.properties.ipAddress
output dnsName string = bastionHost.properties.dnsName
