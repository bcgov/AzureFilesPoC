# Filename: scripts/stop-azure-resources.ps1
# Stop Azure Resources - End of Day Cost Savings
# This script deallocates the VM and deletes Bastion to stop billing
# VM is deallocated (not deleted) - keeps the VM but stops compute billing
# Bastion is deleted via teardown script - saves ~$140/month

param(
    [switch]$SkipConfirmation,
    [switch]$KeepBastion  # Use if you want to keep Bastion running
)

# Load environment variables from azure.env
$envFile = Join-Path $PSScriptRoot "..\azure.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*["]?([^"]*)["]?\s*$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
    Write-Host "Environment variables loaded from azure.env" -ForegroundColor Green
} else {
    Write-Host "azure.env file not found at $envFile" -ForegroundColor Red
    exit 1
}

# Variables from environment
$rgName = $env:RG_AZURE_FILES
$vmName = $env:VM_NAME
$bastionName = $env:BASTION_NAME

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Stopping Azure Resources (Cost Savings)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $rgName"
Write-Host "VM Name: $vmName"
Write-Host "Bastion: $bastionName"
Write-Host ""

# Check current status
Write-Host "Checking current resource status..." -ForegroundColor Yellow
$vmStatus = az vm get-instance-view --name $vmName --resource-group $rgName --query "instanceView.statuses[1].displayStatus" -o tsv 2>$null
$bastionExists = az network bastion show --name $bastionName --resource-group $rgName --query "name" -o tsv 2>$null

Write-Host "   VM Status: $vmStatus"
Write-Host "   Bastion: $(if ($bastionExists) { 'Exists' } else { 'Not deployed' })"
Write-Host ""

if (-not $SkipConfirmation) {
    Write-Host "This will:" -ForegroundColor Yellow
    Write-Host "  1. DEALLOCATE VM (stops billing, keeps VM intact)"
    if (-not $KeepBastion -and $bastionExists) {
        Write-Host "  2. DELETE Bastion (saves ~`$140/month, will recreate on start)" -ForegroundColor Red
    }
    Write-Host ""
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "Cancelled." -ForegroundColor Gray
        exit 0
    }
}

# Step 1: Deallocate VM (NOT delete - just stop billing)
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[1/2] Deallocating VM (stopping, not deleting)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($vmStatus -eq "VM deallocated") {
    Write-Host "VM already deallocated. Skipping." -ForegroundColor Green
} else {
    Write-Host "Deallocating VM..." -ForegroundColor Yellow
    az vm deallocate --name $vmName --resource-group $rgName --no-wait
    Write-Host "VM deallocation started (runs in background)" -ForegroundColor Green
}

# Step 2: Delete Bastion (calls existing teardown script)
if (-not $KeepBastion -and $bastionExists) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[2/2] Deleting Bastion (saves ~`$140/month)" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $teardownBastionScript = Join-Path $PSScriptRoot "bicep\teardown-bastion.ps1"
    
    if (Test-Path $teardownBastionScript) {
        Write-Host "Calling: $teardownBastionScript" -ForegroundColor Yellow
        Write-Host ""
        Push-Location (Join-Path $PSScriptRoot "bicep")
        # Pass 'yes' to auto-confirm since we already confirmed above
        echo "yes" | & $teardownBastionScript
        Pop-Location
    } else {
        Write-Host "teardown-bastion.ps1 not found. Using az CLI directly..." -ForegroundColor Yellow
        az network bastion delete --name $bastionName --resource-group $rgName --no-wait
        Write-Host "Bastion deletion started (runs in background)" -ForegroundColor Green
    }
} elseif ($KeepBastion) {
    Write-Host ""
    Write-Host "[2/2] Keeping Bastion (-KeepBastion flag)" -ForegroundColor Yellow
    Write-Host "Note: Bastion costs ~`$140/month while running" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "[2/2] Bastion not deployed. Skipping." -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Waiting for resources to stop..." -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "(VM deallocates in ~1 min, Bastion deletion takes 5-10 min)"
Write-Host ""

# Wait and verify
$maxWaitMinutes = 12
$checkIntervalSeconds = 30
$elapsed = 0
$vmStopped = ($vmStatus -eq "VM deallocated")
$bastionDeleted = (-not $bastionExists) -or $KeepBastion

while ($elapsed -lt ($maxWaitMinutes * 60) -and (-not $vmStopped -or -not $bastionDeleted)) {
    Start-Sleep -Seconds $checkIntervalSeconds
    $elapsed += $checkIntervalSeconds
    
    if (-not $vmStopped) {
        $vmStatus = az vm get-instance-view --name $vmName --resource-group $rgName --query "instanceView.statuses[1].displayStatus" -o tsv 2>$null
        if ($vmStatus -eq "VM deallocated") {
            Write-Host "   VM: Deallocated" -ForegroundColor Green
            $vmStopped = $true
        }
    }
    
    if (-not $bastionDeleted -and -not $KeepBastion) {
        $bastionCheck = az network bastion show --name $bastionName --resource-group $rgName --query "name" -o tsv 2>$null
        if (-not $bastionCheck) {
            Write-Host "   Bastion: Deleted" -ForegroundColor Green
            $bastionDeleted = $true
        }
    }
    
    if (-not $vmStopped -or -not $bastionDeleted) {
        $waiting = @()
        if (-not $vmStopped) { $waiting += "VM" }
        if (-not $bastionDeleted) { $waiting += "Bastion" }
        Write-Host "   Waiting for: $($waiting -join ', ')... ($([math]::Round($elapsed/60,1)) min)" -ForegroundColor Gray
    }
}

# Final status
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Final Status" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$finalVmStatus = az vm get-instance-view --name $vmName --resource-group $rgName --query "instanceView.statuses[1].displayStatus" -o tsv 2>$null
$finalBastionExists = az network bastion show --name $bastionName --resource-group $rgName --query "name" -o tsv 2>$null

if ($finalVmStatus -eq "VM deallocated") {
    Write-Host "   VM: Deallocated (not billing)" -ForegroundColor Green
} else {
    Write-Host "   VM: $finalVmStatus" -ForegroundColor Yellow
}

if (-not $finalBastionExists) {
    Write-Host "   Bastion: Deleted (not billing)" -ForegroundColor Green
} elseif ($KeepBastion) {
    Write-Host "   Bastion: Running (still billing ~`$140/month)" -ForegroundColor Yellow
} else {
    Write-Host "   Bastion: Still deleting..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Cost savings:" -ForegroundColor Cyan
Write-Host "   - VM compute: Stopped (no charges while deallocated)"
Write-Host "   - Bastion: ~`$140/month saved when deleted"
Write-Host "   - Storage/Disks: Small charges still apply"
Write-Host ""
Write-Host "To start again, run:" -ForegroundColor Yellow
Write-Host "   .\scripts\start-azure-resources.ps1"
