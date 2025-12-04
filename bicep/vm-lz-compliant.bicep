
// ===== Parameters =====
param location string = 'canadacentral'
param vmName string
param vmSize string = 'Standard_D2s_v3'

param adminUsername string = 'azureuser'
@secure()
param sshPublicKey string

param osDiskSizeGb int = 30

// --- Existing network (do NOT create/change VNets in LZ) ---
param vnetName string            // e.g., d5007d-<spoke>-vwan-spoke
param vnetResourceGroup string   // resource group containing the VNet
param subnetName string          // workload subnet name

// --- NSG policy: attach at SUBNET level (guardrail) ---
param nsgName string = '${vmName}-nsg'
param attachNsgToSubnet bool = true

// Allow SSH internally only (policy denies mgmt ports from Internet)
// Set to '' (empty string) to omit the SSH rule entirely.
param allowSshFrom string = 'VirtualNetwork'

// Optional app port allow (e.g., 8080) from specific CIDRs; leave empty to skip
param externalAllowCidrs array = []
param externalAllowPort string = '8080'

// NIC perf
param enableAcceleratedNetworking bool = true

// Diagnostics & monitoring
param enableBootDiagnostics bool = true
param enableAMA bool = true
param enableMDE bool = true

// Optional User‑Assigned MI (UAMI). Leave empty to skip.
param uamiId string = ''

// Tags
param tags object = {
  env: 'dev'
  costCentre: 'JPSS'
  app: 'AzureFiles'
  dataSensitivity: 'ProtectedB'
}

// ===== Existing VNet and subnet (LZ: use platform spoke) =====
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroup)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: vnet
  name: subnetName
}

// ===== NSG (define rules) =====
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: union(
      allowSshFrom != '' ? [
        {
          name: 'allow-ssh-private'
          properties: {
            priority: 100
            access: 'Allow'
            direction: 'Inbound'
            protocol: 'Tcp'
            sourceAddressPrefix: allowSshFrom
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '22'
          }
        }
      ] : [],
      length(externalAllowCidrs) > 0 ? [
        {
          name: 'allow-external-app-port'
          properties: {
            priority: 300
            access: 'Allow'
            direction: 'Inbound'
            protocol: 'Tcp'
            sourceAddressPrefixes: externalAllowCidrs
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: externalAllowPort
          }
        }
      ] : [],
      [
        {
          name: 'allow-azurelb-probes'
          properties: {
            priority: 200
            access: 'Allow'
            direction: 'Inbound'
            protocol: '*'
            sourceAddressPrefix: 'AzureLoadBalancer'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '*'
          }
        }
      ]
    )
  }
}

// ===== Attach NSG to SUBNET (policy requires subnet-level NSG) =====
// Note: Using string concatenation for name because vnet is in a different resource group scope
resource subnetNsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = if (attachNsgToSubnet) {
  name: '${vnetName}/${subnetName}'
  properties: {
    networkSecurityGroup: { id: nsg.id }
  }
}

// ===== NIC (NO public IP) =====
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    enableAcceleratedNetworking: enableAcceleratedNetworking
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: subnet.id }
          privateIPAllocationMethod: 'Dynamic'
          // No publicIpAddress here (guardrail compliance)
        }
      }
    ]
  }
}

// ===== VM =====
var identityType = uamiId == '' ? 'SystemAssigned' : 'SystemAssigned, UserAssigned'
var userAssignedIdentities = uamiId == '' ? {} : { '${uamiId}': {} }

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  identity: {
    type: identityType
    userAssignedIdentities: userAssignedIdentities
  }
  properties: {
    hardwareProfile: { vmSize: vmSize }

    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        osType: 'Linux'
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGb
        managedDisk: { storageAccountType: 'Premium_LRS' }
      }
    }

    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
        patchSettings: {
          patchMode: 'ImageDefault'
          assessmentMode: 'AutomaticByPlatform'
        }
      }
      allowExtensionOperations: true
    }

    networkProfile: { networkInterfaces: [ { id: nic.id } ] }

    // Managed boot diagnostics (no custom Storage Account, no public access)
    diagnosticsProfile: { bootDiagnostics: { enabled: enableBootDiagnostics } }
  }
  tags: tags
}

// ===== Extensions (optional) =====
resource ama 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (enableAMA) {
  name: 'AzureMonitorLinuxAgent'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.36'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: uamiId == '' ? {} : {
      authentication: {
        managedIdentity: {
          'identifier-name': 'mi_res_id'
          'identifier-value': uamiId
        }
      }
    }
  }
}

resource mde 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = if (enableMDE) {
  name: 'MDE.Linux'
  parent: vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.AzureDefenderForServers'
    type: 'MDE.Linux'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      azureResourceId: vm.id
      forceReOnboarding: false
      vNextEnabled: false
      autoUpdate: true
    }
  }
}
