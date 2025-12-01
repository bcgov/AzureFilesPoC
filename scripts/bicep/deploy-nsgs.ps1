az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry-bastion.bicep" --parameters location=$location
az deployment group create --resource-group $resourceGroup --template-file "../bicep/nsg-ag-pssg-azure-files-azure-foundry-pe.bicep" --parameters location=$location

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

$resourceGroup = $env:RG_AZURE_FILES
$location = $env:AZURE_LOCATION
if (-not $location) {
	$location = $env:TARGET_AZURE_REGION
}
$nsgVmName = $env:NSG_VM # Set this in azure.env
$nsgBastionName = $env:NSG_BASTION # Set this in azure.env
$nsgPeName = $env:NSG_PE # Set this in azure.env

if (-not $resourceGroup -or -not $location) {
	Write-Error "Required variables missing. Ensure RG_AZURE_FILES and AZURE_LOCATION (or TARGET_AZURE_REGION) are set in azure.env."
	exit 1
}


# Helper function to check NSG existence
function Test-NsgExists {
	param (
		[string]$nsgName,
		[string]$resourceGroup
	)
	$exists = az network nsg show --name $nsgName --resource-group $resourceGroup --query "name" -o tsv 2>$null
	return ($exists -eq $nsgName)
}

# Deploy NSG for VM subnet
if ($nsgVmName) {
	if (Test-NsgExists -nsgName $nsgVmName -resourceGroup $resourceGroup) {
		Write-Host "NSG '$nsgVmName' already exists in resource group '$resourceGroup'. Skipping creation."
	} else {
		$bicepPathVm = Join-Path $PSScriptRoot "..\\..\\bicep\\nsg-snet-ag-pssg-azure-files-poc-dev-storage.bicep" # Update to your actual NSG Bicep file for VM
		$result = az deployment group create --resource-group $resourceGroup --template-file $bicepPathVm --parameters nsgName=$nsgVmName location=$location 2>&1
		if ($LASTEXITCODE -eq 0) {
			Write-Host "NSG '$nsgVmName' created in resource group '$resourceGroup'."
		} else {
			Write-Error "Failed to create NSG '$nsgVmName': $result"
		}
	}
}

# Deploy NSG for Bastion subnet
if ($nsgBastionName) {
	if (Test-NsgExists -nsgName $nsgBastionName -resourceGroup $resourceGroup) {
		Write-Host "NSG '$nsgBastionName' already exists in resource group '$resourceGroup'. Skipping creation."
	} else {
		$bicepPathBastion = Join-Path $PSScriptRoot "..\\..\\bicep\\nsg-bastion-ag-pssg-azure-files-poc-dev-01.bicep"
		$result = az deployment group create --resource-group $resourceGroup --template-file $bicepPathBastion --parameters nsgName=$nsgBastionName location=$location 2>&1
		if ($LASTEXITCODE -eq 0) {
			Write-Host "NSG '$nsgBastionName' created in resource group '$resourceGroup'."
		} else {
			Write-Error "Failed to create NSG '$nsgBastionName': $result"
		}
	}
}

# Deploy NSG for PE subnet
if ($nsgPeName) {
	if (Test-NsgExists -nsgName $nsgPeName -resourceGroup $resourceGroup) {
		Write-Host "NSG '$nsgPeName' already exists in resource group '$resourceGroup'. Skipping creation."
	} else {
		$bicepPathPe = Join-Path $PSScriptRoot "..\\..\\bicep\\nsg-ag-pssg-azure-files-poc-github-runners.bicep" # Update to your actual NSG Bicep file for PE
		$result = az deployment group create --resource-group $resourceGroup --template-file $bicepPathPe --parameters nsgName=$nsgPeName location=$location 2>&1
		if ($LASTEXITCODE -eq 0) {
			Write-Host "NSG '$nsgPeName' created in resource group '$resourceGroup'."
		} else {
			Write-Error "Failed to create NSG '$nsgPeName': $result"
		}
	}
}


