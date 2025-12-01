# Deploy all subnets (VM, Bastion, PE) in Existing VNet using Bicep and azure.env

$ErrorActionPreference = 'Stop'


# Build subnet array with NSG names from .env
$subnets = @(
    @{ Name = $env:SUBNET_VM; Prefix = $env:SUBNET_VM_PREFIX; Nsg = $env:NSG_VM },
    @{ Name = $env:SUBNET_BASTION; Prefix = $env:SUBNET_BASTION_PREFIX; Nsg = $env:NSG_BASTION },
    @{ Name = $env:SUBNET_PE; Prefix = $env:SUBNET_PE_PREFIX; Nsg = $env:NSG_PE }
)

$envPath = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^([A-Z0-9_]+)="?([^"]+)"?$') {
            $name, $value = $matches[1], $matches[2]
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
} else {
    Write-Error "azure.env file not found at $envPath"
    exit 1
}

$resourceGroup = $env:RG_AZURE_FILES
$vnetName = $env:VNET_SPOKE

foreach ($subnet in $subnets) {
    $subnetName = $subnet.Name
    $addressPrefix = $subnet.Prefix
    $nsgName = $subnet.Nsg
    if (-not $subnetName -or -not $addressPrefix -or -not $nsgName) {
        Write-Host "Skipping subnet with missing name, prefix, or NSG."
        continue
    }
    # Get NSG resource ID
    $nsgId = az network nsg show --name $nsgName --resource-group $resourceGroup --query "id" -o tsv 2>$null
    if (-not $nsgId) {
        Write-Error "NSG '$nsgName' not found in resource group '$resourceGroup'."
        continue
    }
    $existing = az network vnet subnet show --resource-group $resourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
    if ($existing -eq $subnetName) {
        Write-Host "Subnet '$subnetName' already exists in VNet '$vnetName'. Skipping creation."
    } else {
        Write-Host "Creating subnet '$subnetName' in VNet '$vnetName'..."
        $bicepPath = Join-Path $PSScriptRoot "..\..\bicep\subnet-create.bicep"
        $result = az deployment group create --resource-group $resourceGroup --template-file $bicepPath --parameters vnetName=$vnetName vnetResourceGroup=$resourceGroup subnetName=$subnetName addressPrefix=$addressPrefix nsgResourceId=$nsgId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Subnet '$subnetName' created in VNet '$vnetName'."
        } else {
            Write-Error "Failed to create subnet '$subnetName': $result"
            continue
        }
    }
    # Confirm creation with retry (handle Azure eventual consistency)
    $maxTries = 5
    $try = 1
    do {
        Start-Sleep -Seconds 5
        $confirmed = az network vnet subnet show --resource-group $resourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
        if ($confirmed -eq $subnetName) {
            Write-Host "Subnet '$subnetName' confirmed present in VNet '$vnetName'."
            break
        }
        $try++
    } while ($try -le $maxTries)
    if ($confirmed -ne $subnetName) {
        Write-Error "Subnet '$subnetName' could not be created or found after $maxTries attempts."
    }
}
