# IMPORTANT: Always deploy the subnet Bicep module at the VNet's resource group scope (e.g., RG_NETWORKING), not the PoC RG.
# The vnetResourceGroup parameter and --resource-group argument must match the VNet's actual resource group.
# NSGs are created in the PoC RG (RG_AZURE_FILES), but subnets must be created in the VNet's RG (RG_NETWORKING).


# Load variables from azure.env
$envPath = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#') -and $line -match '^([A-Z0-9_]+)="?([^\"]+)"?$') {
            $name, $value = $matches[1], $matches[2]
            [System.Environment]::SetEnvironmentVariable($name, $value, 'Process')
        }
    }
} else {
    Write-Error "azure.env file not found at $envPath"
    exit 1
}

# Debug: Print loaded variable values
Write-Host "DEBUG: RG_AZURE_FILES = '$env:RG_AZURE_FILES'"
Write-Host "DEBUG: VNET_SPOKE = '$env:VNET_SPOKE'"
Write-Host "DEBUG: SUBNET_BASTION = '$env:SUBNET_BASTION'"
Write-Host "DEBUG: SUBNET_BASTION_PREFIX = '$env:SUBNET_BASTION_PREFIX'"
Write-Host "DEBUG: NSG_BASTION = '$env:NSG_BASTION'"


# Use VNet's resource group for subnet deployment (align with working VM subnet pattern)
$resourceGroup = $env:RG_AZURE_FILES
$vnetResourceGroup = $env:RG_NETWORKING
$vnetName = $env:VNET_SPOKE
$subnetName = $env:SUBNET_BASTION
$addressPrefix = $env:SUBNET_BASTION_PREFIX
$nsgName = $env:NSG_BASTION

if (-not $resourceGroup -or -not $vnetName -or -not $subnetName -or -not $addressPrefix -or -not $nsgName) {
    Write-Error "Required variables missing. Ensure RG_AZURE_FILES, VNET_SPOKE, SUBNET_BASTION, SUBNET_BASTION_PREFIX, and NSG_BASTION are set in azure.env."
    exit 1
}

# Get NSG resource ID (from PoC RG)
$nsgId = az network nsg show --name $nsgName --resource-group $resourceGroup --query "id" -o tsv 2>$null
if (-not $nsgId) {
    Write-Error "NSG '$nsgName' not found in resource group '$resourceGroup'."
    exit 1
}

# Idempotent: Check if subnet exists (in VNet RG)
$existing = az network vnet subnet show --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
if ($existing -eq $subnetName) {
    Write-Host "Subnet '$subnetName' already exists in VNet '$vnetName'. Skipping creation."
} else {
    Write-Host "Creating subnet '$subnetName' in VNet '$vnetName'..."
    $bicepPath = Join-Path $PSScriptRoot "..\..\bicep\subnet-create.bicep"
    $parameters = "vnetName=$vnetName vnetResourceGroup=$vnetResourceGroup subnetName=$subnetName addressPrefix=$addressPrefix nsgResourceId=$nsgId"
    $result = az deployment group create --resource-group $vnetResourceGroup --template-file $bicepPath --parameters $parameters 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subnet '$subnetName' created in VNet '$vnetName'."
    } else {
        Write-Error "Failed to create subnet '$subnetName': $result"
        exit 1
    }
}

# Confirm creation with retry (handle Azure eventual consistency, in VNet RG)
$maxTries = 5
$try = 1
do {
    Start-Sleep -Seconds 5
    $confirmed = az network vnet subnet show --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
    if ($confirmed -eq $subnetName) {
        Write-Host "Subnet '$subnetName' confirmed present in VNet '$vnetName'."
        break
    }
    $try++
} while ($try -le $maxTries)
if ($confirmed -ne $subnetName) {
    Write-Error "Subnet '$subnetName' could not be created or found after $maxTries attempts."
    exit 1
}
