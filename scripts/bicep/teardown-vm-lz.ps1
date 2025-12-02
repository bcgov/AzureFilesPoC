# Filename: scripts/bicep/teardown-vm-lz.ps1
# Teardown Virtual Machine
# This script removes the VM and associated resources created for the AI Foundry Landing Zone

# Load environment variables
$envFile = Join-Path $PSScriptRoot "..\..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "azure.env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Variables
$resourceGroup = $env:RG_AZURE_FILES
$vmName = $env:VM_NAME

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Virtual Machine" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "VM Name: $vmName"
Write-Host ""

# Check if VM exists
Write-Host "Checking if VM exists..." -ForegroundColor Yellow
$vm = az vm show `
    --resource-group $resourceGroup `
    --name $vmName `
    --query "{id: id, nics: networkProfile.networkInterfaces[].id, osDisk: storageProfile.osDisk.name, dataDisks: storageProfile.dataDisks[].name}" `
    --output json 2>$null | ConvertFrom-Json

if ($LASTEXITCODE -ne 0 -or $null -eq $vm) {
    Write-Host "VM '$vmName' does not exist. Nothing to remove." -ForegroundColor Yellow
    exit 0
}

Write-Host "VM found: $($vm.id)" -ForegroundColor Green

# Get NIC and NSG details before VM deletion
$nicIds = $vm.nics
$nicNames = @()
$nsgNames = @()

if ($nicIds) {
    Write-Host ""
    Write-Host "Found Network Interfaces:" -ForegroundColor Cyan
    foreach ($nicId in $nicIds) {
        $nicName = $nicId.Split('/')[-1]
        $nicNames += $nicName
        Write-Host "  - $nicName" -ForegroundColor White
        
        # Get NSG associated with NIC
        $nsg = az network nic show --ids $nicId --query "networkSecurityGroup.id" --output tsv 2>$null
        if (-not [string]::IsNullOrEmpty($nsg)) {
            $nsgName = $nsg.Split('/')[-1]
            if ($nsgNames -notcontains $nsgName) {
                $nsgNames += $nsgName
            }
        }
    }
}

# Get disk names
$osDiskName = $vm.osDisk
$dataDisks = $vm.dataDisks

Write-Host ""
Write-Host "Found Disks:" -ForegroundColor Cyan
Write-Host "  - OS Disk: $osDiskName" -ForegroundColor White
if ($dataDisks) {
    foreach ($disk in $dataDisks) {
        Write-Host "  - Data Disk: $disk" -ForegroundColor White
    }
}

if ($nsgNames) {
    Write-Host ""
    Write-Host "Found NSGs:" -ForegroundColor Cyan
    foreach ($nsgName in $nsgNames) {
        Write-Host "  - $nsgName" -ForegroundColor White
    }
}

# Confirm deletion
Write-Host ""
Write-Host "⚠️  WARNING: This will delete the following resources:" -ForegroundColor Red
Write-Host "  - VM: $vmName" -ForegroundColor Yellow
Write-Host "  - NIC(s): $($nicNames -join ', ')" -ForegroundColor Yellow
Write-Host "  - OS Disk: $osDiskName" -ForegroundColor Yellow
if ($dataDisks) {
    Write-Host "  - Data Disk(s): $($dataDisks -join ', ')" -ForegroundColor Yellow
}
if ($nsgNames) {
    Write-Host "  - NSG(s): $($nsgNames -join ', ')" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "This action cannot be undone." -ForegroundColor Red
$confirmation = Read-Host "Type 'yes' to confirm deletion"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

# Delete VM (this will also delete OS disk if deleteOption is set to Delete)
Write-Host ""
Write-Host "Deleting VM '$vmName'..." -ForegroundColor Yellow
az vm delete `
    --resource-group $resourceGroup `
    --name $vmName `
    --yes

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to delete VM. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host "✅ VM deleted successfully!" -ForegroundColor Green

# Delete NICs
if ($nicNames) {
    Write-Host ""
    Write-Host "Deleting Network Interfaces..." -ForegroundColor Yellow
    foreach ($nicName in $nicNames) {
        Write-Host "  Deleting NIC: $nicName" -ForegroundColor Yellow
        az network nic delete `
            --resource-group $resourceGroup `
            --name $nicName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ NIC '$nicName' deleted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Failed to delete NIC '$nicName'" -ForegroundColor Yellow
        }
    }
}

# Delete NSGs (if they exist and are not attached to subnets)
if ($nsgNames) {
    Write-Host ""
    Write-Host "Deleting Network Security Groups..." -ForegroundColor Yellow
    foreach ($nsgName in $nsgNames) {
        # Check if NSG is attached to any subnets
        $subnets = az network nsg show `
            --resource-group $resourceGroup `
            --name $nsgName `
            --query "subnets[].id" `
            --output tsv 2>$null
        
        if (-not [string]::IsNullOrEmpty($subnets)) {
            Write-Host "  ⚠️  NSG '$nsgName' is attached to subnets. Skipping deletion." -ForegroundColor Yellow
            Write-Host "     Detach from subnets first if you want to delete it." -ForegroundColor Yellow
        } else {
            Write-Host "  Deleting NSG: $nsgName" -ForegroundColor Yellow
            az network nsg delete `
                --resource-group $resourceGroup `
                --name $nsgName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ NSG '$nsgName' deleted" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Failed to delete NSG '$nsgName'" -ForegroundColor Yellow
            }
        }
    }
}

# Delete OS Disk (if not automatically deleted with VM)
Write-Host ""
Write-Host "Checking for remaining OS disk..." -ForegroundColor Yellow
$diskExists = az disk show `
    --resource-group $resourceGroup `
    --name $osDiskName `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($diskExists)) {
    Write-Host "OS Disk '$osDiskName' still exists. Deleting..." -ForegroundColor Yellow
    az disk delete `
        --resource-group $resourceGroup `
        --name $osDiskName `
        --yes
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ OS Disk deleted" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Failed to delete OS Disk" -ForegroundColor Yellow
    }
} else {
    Write-Host "OS Disk was automatically deleted with VM" -ForegroundColor Green
}

# Delete Data Disks (if any and not automatically deleted)
if ($dataDisks) {
    Write-Host ""
    Write-Host "Checking for remaining data disks..." -ForegroundColor Yellow
    foreach ($diskName in $dataDisks) {
        $diskExists = az disk show `
            --resource-group $resourceGroup `
            --name $diskName `
            --query "id" `
            --output tsv 2>$null
        
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($diskExists)) {
            Write-Host "Data Disk '$diskName' still exists. Deleting..." -ForegroundColor Yellow
            az disk delete `
                --resource-group $resourceGroup `
                --name $diskName `
                --yes
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Data Disk '$diskName' deleted" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Failed to delete Data Disk '$diskName'" -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ VM '$vmName' and associated resources removed!" -ForegroundColor Green
