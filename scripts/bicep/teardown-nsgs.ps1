# Teardown All Network Security Groups
# This script removes all NSGs created for the AI Foundry Landing Zone

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
$rgNetworking = $env:RG_NETWORKING
$nsgVM = $env:NSG_VM
$nsgBastion = $env:NSG_BASTION
$nsgPE = $env:NSG_PE

$nsgs = @(
    @{Name = $nsgPE; Description = "Private Endpoints NSG"},
    @{Name = $nsgBastion; Description = "Bastion NSG"},
    @{Name = $nsgVM; Description = "VM NSG"}
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tearing Down Network Security Groups" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $rgNetworking"
Write-Host ""

# Confirm deletion
Write-Host "⚠️  WARNING: This will delete the following NSGs:" -ForegroundColor Red
foreach ($nsg in $nsgs) {
    Write-Host "  - $($nsg.Name) ($($nsg.Description))" -ForegroundColor Yellow
}
Write-Host ""
$confirmation = Read-Host "Type 'yes' to confirm deletion of all NSGs"

if ($confirmation -ne 'yes') {
    Write-Host "Deletion cancelled." -ForegroundColor Yellow
    exit 0
}

$successCount = 0
$failCount = 0
$notFoundCount = 0

foreach ($nsg in $nsgs) {
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "Processing: $($nsg.Name)" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    
    # Check if NSG exists
    Write-Host "Checking if NSG exists..." -ForegroundColor Yellow
    $nsgId = az network nsg show `
        --resource-group $rgNetworking `
        --name $nsg.Name `
        --query "id" `
        --output tsv 2>$null
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($nsgId)) {
        Write-Host "NSG '$($nsg.Name)' does not exist. Skipping." -ForegroundColor Yellow
        $notFoundCount++
        continue
    }
    
    Write-Host "NSG found: $nsgId" -ForegroundColor Green
    
    # Check if NSG is attached to any subnets
    Write-Host "Checking for attached subnets..." -ForegroundColor Yellow
    $subnets = az network nsg show `
        --resource-group $rgNetworking `
        --name $nsg.Name `
        --query "subnets[].id" `
        --output tsv 2>$null
    
    if (-not [string]::IsNullOrEmpty($subnets)) {
        Write-Host "⚠️  WARNING: NSG '$($nsg.Name)' is attached to subnets:" -ForegroundColor Yellow
        $subnets -split "`n" | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Yellow
        }
        Write-Host "Attempting to delete anyway (Azure will detach automatically)..." -ForegroundColor Yellow
    }
    
    # Delete NSG
    Write-Host "Deleting NSG '$($nsg.Name)'..." -ForegroundColor Yellow
    az network nsg delete `
        --resource-group $rgNetworking `
        --name $nsg.Name
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ NSG '$($nsg.Name)' deleted successfully!" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "❌ Failed to delete NSG '$($nsg.Name)'." -ForegroundColor Red
        $failCount++
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Teardown Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Total NSGs processed: $($nsgs.Count)" -ForegroundColor White
Write-Host "Successfully deleted: $successCount" -ForegroundColor Green
Write-Host "Not found (skipped): $notFoundCount" -ForegroundColor Yellow
Write-Host "Failed to delete: $failCount" -ForegroundColor Red

if ($failCount -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Some NSGs failed to delete. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ All NSG teardown operations completed!" -ForegroundColor Green
