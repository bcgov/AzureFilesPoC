# IMPORTANT: Always deploy the subnet Bicep module at the VNet's resource group scope (e.g., RG_NETWORKING), not the PoC RG.
# The vnetResourceGroup parameter and --resource-group argument must match the VNet's actual resource group.
# Deploy VM Subnet in Existing VNet using Bicep and azure.env

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

# Set parameters


# Debug: Print loaded variable values
Write-Host "DEBUG: RG_AZURE_FILES = '$env:RG_AZURE_FILES'"
Write-Host "DEBUG: VNET_SPOKE = '$env:VNET_SPOKE'"
Write-Host "DEBUG: SUBNET_VM = '$env:SUBNET_VM'"
Write-Host "DEBUG: SUBNET_VM_PREFIX = '$env:SUBNET_VM_PREFIX'"
Write-Host "DEBUG: NSG_VM = '$env:NSG_VM'"


$resourceGroup = $env:RG_AZURE_FILES
$vnetResourceGroup = $env:RG_NETWORKING
$vnetName = $env:VNET_SPOKE
$subnetName = $env:SUBNET_VM
$addressPrefix = $env:SUBNET_VM_PREFIX
$nsgName = $env:NSG_VM

if (-not $resourceGroup -or -not $vnetResourceGroup -or -not $vnetName -or -not $subnetName -or -not $addressPrefix -or -not $nsgName) {
    Write-Error "Required variables missing. Ensure RG_AZURE_FILES, RG_NETWORKING, VNET_SPOKE, SUBNET_VM, SUBNET_VM_PREFIX, and NSG_VM are set in azure.env."
    exit 1
}

# Get NSG resource ID
$nsgId = az network nsg show --name $nsgName --resource-group $resourceGroup --query "id" -o tsv 2>$null
if (-not $nsgId) {
    Write-Error "NSG '$nsgName' not found in resource group '$resourceGroup'."
    exit 1
}

# Idempotent: Check if subnet exists
$existing = az network vnet subnet show --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
if ($existing -eq $subnetName) {
    # Check current address prefix
    $currentPrefix = az network vnet subnet show --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName --query "addressPrefix" -o tsv 2>$null
    if ($currentPrefix -eq $addressPrefix) {
        Write-Host "Subnet '$subnetName' already exists with correct address prefix '$addressPrefix'. Skipping."
    } else {
        Write-Host "Subnet '$subnetName' exists but has different address prefix '$currentPrefix'. Deleting and recreating with '$addressPrefix'..."
        az network vnet subnet delete --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to delete existing subnet '$subnetName'."
            exit 1
        }
        # Now create
        $bicepPath = Join-Path $PSScriptRoot "..\..\bicep\subnet-create.bicep"
        $result = az deployment group create --resource-group $vnetResourceGroup --template-file $bicepPath --parameters vnetName=$vnetName vnetResourceGroup=$vnetResourceGroup subnetName=$subnetName addressPrefix=$addressPrefix nsgResourceId=$nsgId 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Subnet '$subnetName' recreated in VNet '$vnetName'."
        } else {
            Write-Error "Failed to recreate subnet '$subnetName': $result"
            exit 1
        }
    }
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

# Confirm creation with retry (handle Azure eventual consistency)
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
