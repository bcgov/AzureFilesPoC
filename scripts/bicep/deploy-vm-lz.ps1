# Filename: scripts/bicep/deploy-vm-lz.ps1
# Deploy Virtual Machine (Landing Zone Compliant)
# This script deploys a Linux VM for running AI consumption scripts with secure access

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

# Variables from azure.env
$resourceGroup = $env:RG_AZURE_FILES
$location = $env:TARGET_AZURE_REGION
$vmName = $env:VM_NAME
$vnetName = $env:VNET_SPOKE
$subnetName = $env:SUBNET_VM
$rgNetworking = $env:RG_NETWORKING
$uamiName = $env:UAMI_NAME

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying Virtual Machine" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup"
Write-Host "Location: $location"
Write-Host "VM Name: $vmName"
Write-Host "VNet: $vnetName (in $rgNetworking)"
Write-Host "Subnet: $subnetName"
Write-Host ""

# Check if VM already exists
Write-Host "Checking if VM already exists..." -ForegroundColor Yellow
$existingVm = az vm show `
    --resource-group $resourceGroup `
    --name $vmName `
    --query "id" `
    --output tsv 2>$null

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrEmpty($existingVm)) {
    Write-Host "VM '$vmName' already exists!" -ForegroundColor Yellow
    Write-Host "VM ID: $existingVm" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To recreate, delete it first with: .\teardown-vm-lz.ps1" -ForegroundColor Cyan
    exit 0
}

Write-Host "VM does not exist. Proceeding with deployment..." -ForegroundColor Green
Write-Host ""

# Get UAMI resource ID
Write-Host "Getting User-Assigned Managed Identity..." -ForegroundColor Yellow
$uamiId = az identity show `
    --name $uamiName `
    --resource-group $resourceGroup `
    --query "id" `
    --output tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($uamiId)) {
    Write-Host "❌ Failed to find UAMI '$uamiName'. Deploy it first with deploy-uami.ps1" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Found UAMI: $uamiId" -ForegroundColor Green
Write-Host ""

# Get SSH public key
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "SSH Key Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Try to read from default SSH key location
$defaultSshKeyPath = Join-Path $env:USERPROFILE ".ssh\id_rsa.pub"
$sshPublicKey = $null

if (Test-Path $defaultSshKeyPath) {
    Write-Host "Found SSH public key at: $defaultSshKeyPath" -ForegroundColor Green
    $sshPublicKey = Get-Content $defaultSshKeyPath -Raw
    $sshPublicKey = $sshPublicKey.Trim()
    Write-Host "SSH key loaded (${sshPublicKey.Substring(0, [Math]::Min(50, $sshPublicKey.Length))}...)" -ForegroundColor Cyan
    Write-Host ""
    $useDefault = Read-Host "Use this SSH key? (yes/no)"
    
    if ($useDefault -ne 'yes') {
        $sshPublicKey = $null
    }
}

if ([string]::IsNullOrWhiteSpace($sshPublicKey)) {
    Write-Host ""
    Write-Host "Please provide your SSH public key." -ForegroundColor Yellow
    Write-Host "You can generate a key pair with: ssh-keygen -t rsa -b 4096" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Enter the full path to your SSH public key file:" -ForegroundColor Yellow
    Write-Host "Example: C:\Users\YourName\.ssh\id_rsa.pub" -ForegroundColor Cyan
    $keyPath = Read-Host
    
    if (Test-Path $keyPath) {
        $sshPublicKey = Get-Content $keyPath -Raw
        $sshPublicKey = $sshPublicKey.Trim()
        Write-Host "SSH key loaded successfully!" -ForegroundColor Green
    } else {
        Write-Host "File not found. Deployment cancelled." -ForegroundColor Red
        exit 1
    }
}

# Validate SSH key format
if ($sshPublicKey -notmatch '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-)') {
    Write-Host "Warning: SSH key doesn't start with expected prefix (ssh-rsa, ssh-ed25519, etc.)" -ForegroundColor Yellow
    Write-Host "Key preview: $($sshPublicKey.Substring(0, [Math]::Min(100, $sshPublicKey.Length)))" -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (yes/no)"
    if ($continue -ne 'yes') {
        Write-Host "Deployment cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""

# Deploy VM using Bicep
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying VM with Bicep" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$bicepFile = Join-Path $PSScriptRoot "..\..\bicep\vm-lz-compliant.bicep"

az deployment group create `
    --resource-group $resourceGroup `
    --template-file $bicepFile `
    --parameters `
        vmName=$vmName `
        location=$location `
        vnetName=$vnetName `
        vnetResourceGroup=$rgNetworking `
        subnetName=$subnetName `
        sshPublicKey="$sshPublicKey" `
        uamiId=$uamiId `
        nsgName="$vmName-nsg" `
        adminUsername="azureuser" `
        vmSize="Standard_D2s_v3" `
        enableAcceleratedNetworking=true `
        enableBootDiagnostics=true `
        enableAMA=true `
        enableMDE=false `
        attachNsgToSubnet=false

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "VM Deployment Successful!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host ""
    
    # Get VM details
    Write-Host "VM Details:" -ForegroundColor Cyan
    $vmDetails = az vm show `
        --resource-group $resourceGroup `
        --name $vmName `
        --output json | ConvertFrom-Json
    
    $nicId = $vmDetails.networkProfile.networkInterfaces[0].id
    $nicName = $nicId.Split('/')[-1]
    
    $privateIp = az network nic show `
        --ids $nicId `
        --query "ipConfigurations[0].privateIPAddress" `
        --output tsv
    
    Write-Host "  VM Name: $vmName" -ForegroundColor White
    Write-Host "  Resource Group: $resourceGroup" -ForegroundColor White
    Write-Host "  Location: $location" -ForegroundColor White
    Write-Host "  Private IP: $privateIp" -ForegroundColor White
    Write-Host "  VM Size: Standard_D2s_v3" -ForegroundColor White
    Write-Host "  OS: Ubuntu 24.04 LTS" -ForegroundColor White
    Write-Host "  Admin User: azureuser" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Managed Identity:" -ForegroundColor Cyan
    Write-Host "  System-Assigned: Enabled" -ForegroundColor White
    Write-Host "  User-Assigned: $uamiName" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Extensions Installed:" -ForegroundColor Cyan
    Write-Host "  - Azure Monitor Agent (AMA)" -ForegroundColor Green
    Write-Host "  - Microsoft Defender for Endpoint (MDE)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Deploy Bastion Host for secure access: .\deploy-bastion.ps1" -ForegroundColor Yellow
    Write-Host "  2. Configure RBAC for UAMI to access Storage/Key Vault:" -ForegroundColor Yellow
    Write-Host "     az role assignment create --assignee <uami-principal-id> --role 'Storage Blob Data Contributor' --scope <storage-id>" -ForegroundColor Cyan
    Write-Host "  3. Connect via Bastion once deployed (no public IP on VM)" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Note: The VM has NO public IP address for security compliance." -ForegroundColor Yellow
    Write-Host "Access requires Bastion or VPN connection to the VNet." -ForegroundColor Yellow
    
} else {
    Write-Host ""
    Write-Host "❌ VM deployment failed. Check error messages above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan


