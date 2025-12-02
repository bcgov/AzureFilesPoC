# Filename: scripts/bicep/teardown-subnet-pe.ps1
<#
    Teardown Private Endpoint Subnet from Existing VNet using Azure CLI
#>

# Load environment variables from azure.env
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)="([^"]*)"$') {
            $key = $matches[1]
            $value = $matches[2]
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

# Debug: Print loaded variable values
Write-Host "DEBUG: RG_NETWORKING = '$env:RG_NETWORKING'"
Write-Host "DEBUG: VNET_SPOKE = '$env:VNET_SPOKE'"
Write-Host "DEBUG: SUBNET_PE = '$env:SUBNET_PE'"

$vnetResourceGroup = $env:RG_NETWORKING
$vnetName = $env:VNET_SPOKE
$subnetName = $env:SUBNET_PE

if (-not $vnetResourceGroup -or -not $vnetName -or -not $subnetName) {
    Write-Error "Required variables missing. Ensure RG_NETWORKING, VNET_SPOKE, and SUBNET_PE are set in azure.env."
    exit 1
}

# Idempotent: Check if subnet exists
$existing = az network vnet subnet show --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName --query "name" -o tsv 2>$null
if ($existing -eq $subnetName) {
    Write-Host "Deleting subnet '$subnetName' from VNet '$vnetName'..."
    $result = az network vnet subnet delete --resource-group $vnetResourceGroup --vnet-name $vnetName --name $subnetName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subnet '$subnetName' deleted from VNet '$vnetName'."
    } else {
        Write-Error "Failed to delete subnet '$subnetName': $result"
        exit 1
    }
} else {
    Write-Host "Subnet '$subnetName' does not exist in VNet '$vnetName'. Skipping deletion."
}