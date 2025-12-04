// IMPORTANT: Always deploy this module at the VNet's resource group scope (e.g., RG_NETWORKING), not the PoC RG.
// The vnetResourceGroup parameter and --resource-group argument must match the VNet's actual resource group.
// NSGs are created in the PoC RG (RG_AZURE_FILES), but subnets must be created in the VNet's RG (RG_NETWORKING).
// subnet-create.bicep
// Module to create a subnet in an existing VNet
// IMPORTANT: You MUST deploy this module at the resource group scope of the VNet (not the PoC/app RG).
// Pass the VNet's resource group as the vnetResourceGroup parameter and use it for the deployment scope.
// Example: az deployment group create --resource-group <VNET_RG> --template-file subnet-create.bicep --parameters vnetResourceGroup=<VNET_RG> ...

param vnetName string
// Note: vnetResourceGroup is passed by the parent Bicep file to set the module deployment scope
// It is not used directly in this module as the scope is determined at deployment time
param subnetName string
param addressPrefix string
param nsgResourceId string = '' // Optional: NSG to associate
param routeTableResourceId string = '' // Optional: Route Table to associate
param isPrivateEndpointSubnet bool = false // Set to true for subnets that will host private endpoints

resource vnet 'Microsoft.Network/virtualNetworks@2024-10-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-10-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: addressPrefix
    // Optionally associate NSG
    networkSecurityGroup: empty(nsgResourceId) ? null : {
      id: nsgResourceId
    }
    // Optionally associate Route Table
    routeTable: empty(routeTableResourceId) ? null : {
      id: routeTableResourceId
    }
    // Disable network policies for private endpoints if this is a PE subnet
    privateEndpointNetworkPolicies: isPrivateEndpointSubnet ? 'Disabled' : null
    privateLinkServiceNetworkPolicies: isPrivateEndpointSubnet ? 'Disabled' : null
  }
}

output subnetId string = subnet.id
