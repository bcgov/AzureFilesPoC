# azure_full_inventory.ps1
# Comprehensive Azure inventory script for BC Gov and enterprise landing zones (PowerShell variant)
# Requires: Azure CLI, jq (optional for advanced merging), PowerShell 7+, and required Azure CLI extensions

param()

# Set strict mode
Set-StrictMode -Version Latest

# Resolve script and output paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Resolve-Path "$ScriptDir\..\..\.."
$OutputDir = Join-Path $ProjectRoot ".env"
$OutputFile = Join-Path $OutputDir "azure_full_inventory.json"
$LogFile = Join-Path $OutputDir "azure_inventory.log"

if (!(Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
if (!(Test-Path $LogFile)) { New-Item -ItemType File -Path $LogFile | Out-Null }

# Tool checks
foreach ($tool in @('az')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Required tool '$tool' is not installed or not in PATH."
        exit 1
    }
}

# Ensure user is logged in
if (-not (az account show 2>$null)) {
    Write-Error "You are not logged in to Azure. Please run 'az login' and try again."
    exit 1
}

# Initialize output JSON
"{}" | Set-Content -Path $OutputFile

# Helper: Run az command and merge result into output JSON
function Merge-Json {
    param(
        [string]$Key,
        [string]$AzCmd
    )
    try {
        $result = Invoke-Expression $AzCmd | ConvertFrom-Json
    } catch {
        $result = @()
    }
    $json = Get-Content $OutputFile | ConvertFrom-Json
    $json | Add-Member -NotePropertyName $Key -NotePropertyValue $result -Force
    $json | ConvertTo-Json -Depth 100 | Set-Content $OutputFile
}

# Collect resources in parallel (PowerShell jobs)
$jobs = @()
$jobs += Start-Job { Merge-Json -Key 'subscription' -AzCmd 'az account show --query "{id:id, name:name, tenantId:tenantId, state:state}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'tenantId' -AzCmd 'az account show --query "tenantId" --output json' }
$jobs += Start-Job { Merge-Json -Key 'resourceGroups' -AzCmd 'az group list --query "[].{name:name, id:id, location:location, tags:tags}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'resources' -AzCmd 'az resource list --query "[].{id:id, name:name, type:type, resourceGroup:resourceGroup, location:location, sku:sku, tags:tags}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'virtualNetworks' -AzCmd 'az network vnet list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, addressSpace:addressSpace.addressPrefixes, subnets:[subnets][].{id:id, name:name, addressPrefix:addressPrefix, nsgId:networkSecurityGroup.id, privateEndpointNetworkPolicies:privateEndpointNetworkPolicies, privateLinkServiceNetworkPolicies:privateLinkServiceNetworkPolicies}, dnsServers:dhcpOptions.dnsServers}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'networkSecurityGroups' -AzCmd 'az network nsg list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, securityRules:securityRules[].{name:name, direction:direction, access:access, protocol:protocol, sourceAddressPrefix:sourceAddressPrefix, destinationAddressPrefix:destinationAddressPrefix, sourcePortRange:sourcePortRange, destinationPortRange:destinationPortRange}}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'publicIPAddresses' -AzCmd 'az network public-ip list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, ipAddress:ipAddress, sku:sku.name, publicIPAllocationMethod:publicIPAllocationMethod, dnsSettings:dnsSettings.domainNameLabel}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'privateIPAddresses' -AzCmd 'az network nic list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, privateIpAddress:ipConfigurations[].privateIPAddress, subnetId:ipConfigurations[].subnet.id, publicIpId:ipConfigurations[].publicIPAddress.id}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'vpnGateways' -AzCmd 'az network vpn-gateway list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, bgpSettings:bgpSettings, connections:[connections][].{name:name, id:id, remoteVnetId:remoteVnet.id, protocolType:protocolType}}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'connections' -AzCmd 'az network vpn-connection list --query "[].{id:id, name:name, resourceGroup:resourceGroup, connectionType:connectionType, vnetGatewayId:virtualNetworkGateway.id, expressRouteCircuitId:expressRouteCircuit.id, connectionStatus:connectionStatus}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'routeTables' -AzCmd 'az network route-table list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, routes:[routes][].{name:name, id:id, addressPrefix:addressPrefix, nextHopType:nextHopType, nextHopIpAddress:nextHopIpAddress}}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'virtualHubs' -AzCmd 'az network vhub list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, addressPrefix:addressPrefix, virtualWanId:virtualWan.id, routingState:routingState}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'privateEndpoints' -AzCmd 'az network private-endpoint list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, subnetId:subnet.id, privateLinkServiceConnections:privateLinkServiceConnections[].{name:name, privateLinkServiceId:privateLinkServiceId, groupIds:groupIds}}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'storageAccounts' -AzCmd 'az storage account list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, kind:kind, sku:sku.name}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'registeredApplications' -AzCmd 'az ad app list --query "[].{id:appId, displayName:displayName, identifierUris:identifierUris, createdDateTime:createdDateTime}" --output json' }
$jobs += Start-Job { Merge-Json -Key 'roleAssignments' -AzCmd 'az role assignment list --query "[].{id:id, principalName:principalName, roleDefinitionName:roleDefinitionName, scope:scope, principalType:principalType}" --output json' }

# Wait for all jobs
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job

# Additional logic for onboarding, merging, and cleanup can be added here, following the Bash script's structure.
# For brevity, this script focuses on the main inventory collection and merging logic.

Write-Host "Inventory has been successfully written to $OutputFile"
