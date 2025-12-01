# Load environment variables from azure.env
$envFile = "..\..\azure.env"
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
    Write-Host "Warning: azure.env file not found at $envFile" -ForegroundColor Yellow
    exit 1
}

# Variables from environment
$rgName = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_REGION
$vnetName = $env:VNET_SPOKE
$vnetRg = $env:RG_NETWORKING
$subnetName = $env:SUBNET_BASTION
$bastionName = $env:BASTION_NAME
$publicIpName = $env:BASTION_PIP

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying Azure Bastion" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: `"$rgName`"" -ForegroundColor White
Write-Host "Location: `"$location`"" -ForegroundColor White
Write-Host "Bastion Name: `"$bastionName`"" -ForegroundColor White
Write-Host "VNet: `"$vnetName`" (in `"$vnetRg`")" -ForegroundColor White
Write-Host "Subnet: `"$subnetName`"" -ForegroundColor White
Write-Host ""

# Check if Bastion already exists
Write-Host "Checking if Bastion already exists..." -ForegroundColor Yellow
$existingBastion = az network bastion show --name $bastionName --resource-group $rgName 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Bastion '$bastionName' already exists. Skipping deployment." -ForegroundColor Green
    
    # Get Bastion details
    $bastionDetails = az network bastion show --name $bastionName --resource-group $rgName --query "{Name:name, ResourceGroup:resourceGroup, Location:location, ProvisioningState:provisioningState, DnsName:dnsName}" --output json | ConvertFrom-Json
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Bastion Already Deployed" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Name: $($bastionDetails.Name)" -ForegroundColor White
    Write-Host "Resource Group: $($bastionDetails.ResourceGroup)" -ForegroundColor White
    Write-Host "Location: $($bastionDetails.Location)" -ForegroundColor White
    Write-Host "Provisioning State: $($bastionDetails.ProvisioningState)" -ForegroundColor White
    Write-Host "DNS Name: $($bastionDetails.DnsName)" -ForegroundColor White
    Write-Host ""
    Write-Host "Access your VM via Azure Portal:" -ForegroundColor Cyan
    Write-Host "https://portal.azure.com/#@bcgov.onmicrosoft.com/resource/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$rgName/providers/Microsoft.Compute/virtualMachines/$env:VM_NAME/connect" -ForegroundColor Yellow
    
    exit 0
}
Write-Host "Bastion does not exist. Proceeding with deployment..." -ForegroundColor Green
Write-Host ""

# Deploy Bastion using Bicep
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying Bastion with Bicep" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

az deployment group create `
    --resource-group $rgName `
    --template-file "..\..\bicep\bastion.bicep" `
    --parameters `
        bastionName=$bastionName `
        location=$location `
        vnetName=$vnetName `
        vnetResourceGroup=$vnetRg `
        subnetName=$subnetName `
        publicIpName=$publicIpName `
        skuName=Standard

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Bastion Deployment Successful!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    
    # Get Bastion details
    $bastionDetails = az network bastion show --name $bastionName --resource-group $rgName --query "{Name:name, ResourceGroup:resourceGroup, Location:location, ProvisioningState:provisioningState, DnsName:dnsName}" --output json | ConvertFrom-Json
    
    Write-Host "Name: $($bastionDetails.Name)" -ForegroundColor White
    Write-Host "Resource Group: $($bastionDetails.ResourceGroup)" -ForegroundColor White
    Write-Host "Location: $($bastionDetails.Location)" -ForegroundColor White
    Write-Host "Provisioning State: $($bastionDetails.ProvisioningState)" -ForegroundColor White
    Write-Host "DNS Name: $($bastionDetails.DnsName)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Access your VM via Azure Portal:" -ForegroundColor White
    Write-Host "   https://portal.azure.com/#@bcgov.onmicrosoft.com/resource/subscriptions/$env:AZURE_SUBSCRIPTION_ID/resourceGroups/$rgName/providers/Microsoft.Compute/virtualMachines/$env:VM_NAME/connect" -ForegroundColor Yellow
    Write-Host "2. Click 'Connect' → 'Bastion'" -ForegroundColor White
    Write-Host "3. Enter username: azureuser" -ForegroundColor White
    Write-Host "4. Use SSH private key authentication" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Bastion deployment failed. Check error messages above." -ForegroundColor Red
    exit 1
}

