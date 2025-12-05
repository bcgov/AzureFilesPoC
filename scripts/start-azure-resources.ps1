# Filename: scripts/start-azure-resources.ps1
# Start Azure Resources - Morning Startup
# This script starts the VM and deploys Bastion for secure access
# Calls existing deploy scripts for consistency

param(
    [switch]$SkipBastion  # Use if you don't need Bastion access
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
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Starting Azure Resources" -ForegroundColor Cyan
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

# Step 1: Start VM (if deallocated)
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "[1/2] Starting VM" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if ($vmStatus -eq "VM running") {
    Write-Host "VM already running. Skipping." -ForegroundColor Green
} elseif ($vmStatus -eq "VM deallocated" -or $vmStatus -eq "VM stopped") {
    Write-Host "Starting VM..." -ForegroundColor Yellow
    az vm start --name $vmName --resource-group $rgName
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VM started successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to start VM. Check error above." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "VM status: $vmStatus - attempting to start..." -ForegroundColor Yellow
    az vm start --name $vmName --resource-group $rgName
}

Write-Host ""

# Step 2: Deploy Bastion (calls existing deploy script)
if (-not $SkipBastion) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "[2/2] Deploying Bastion" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    
    $deployBastionScript = Join-Path $PSScriptRoot "bicep\deploy-bastion.ps1"
    
    if (Test-Path $deployBastionScript) {
        Write-Host "Calling: $deployBastionScript" -ForegroundColor Yellow
        Write-Host ""
        Push-Location (Join-Path $PSScriptRoot "bicep")
        & $deployBastionScript
        Pop-Location
    } else {
        Write-Host "deploy-bastion.ps1 not found at: $deployBastionScript" -ForegroundColor Red
        Write-Host "Bastion deployment skipped." -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "[2/2] Skipping Bastion deployment (-SkipBastion flag)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Resources Ready!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Connect to VM:" -ForegroundColor Cyan
Write-Host "  az network bastion ssh --name $bastionName --resource-group $rgName --target-resource-id `"/subscriptions/$subscriptionId/resourceGroups/$rgName/providers/Microsoft.Compute/virtualMachines/$vmName`" --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa_azure"
Write-Host ""
Write-Host "End of day, run:" -ForegroundColor Yellow
Write-Host "  .\scripts\stop-azure-resources.ps1"
