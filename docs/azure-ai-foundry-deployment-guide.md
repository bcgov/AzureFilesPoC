# Azure AI Foundry Landing Zone - Complete Deployment Guide

This comprehensive guide walks through the complete deployment of an Azure AI Foundry landing zone with secure private connectivity. The end result is a VM that can securely consume AI models through Azure AI Foundry APIs without internet exposure.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [SSH Key Creation](#ssh-key-creation)
4. [Phase 1: Foundation (Network & Security)](#phase-1-foundation-network--security)
5. [Phase 2: Storage, Security & Monitoring](#phase-2-storage-security--monitoring)
6. [Phase 3: Compute Resources](#phase-3-compute-resources)
7. [Phase 4: AI Services (Azure AI Foundry)](#phase-4-ai-services-azure-ai-foundry)
8. [Phase 5: Private Connectivity](#phase-5-private-connectivity)
9. [Validation & Testing](#validation--testing)
10. [Troubleshooting](#troubleshooting)
11. [Teardown & Cleanup](#teardown--cleanup)

## Prerequisites

### Required Software
- **Azure CLI** (latest version)
- **PowerShell 5.1+** (Windows) or PowerShell Core (cross-platform)
- **Git** for repository cloning
- **SSH client** for VM access

### Azure Permissions
- **Subscription Contributor** role (or equivalent)
- **User Access Administrator** role (for managed identity assignments)
- Access to **Azure landing zone** resources (VNets, resource groups)

### Azure Landing Zone Resources
Your organization must provide these pre-existing resources:
- Azure subscription
- Virtual network (VNet) in canadacentral
- Networking resource group (RG_NETWORKING)
- Network security policies allowing private endpoints

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/bcgov/AzureFilesPoC.git
cd AzureFilesPoC
```

### 2. Configure Environment Variables
```bash
# Copy template and edit
cp azure.env.template azure.env

# Edit azure.env with your values (this file is gitignored)
notepad azure.env  # or your preferred editor
```

**Required Variables:**
```bash
# Subscription and regions
AZURE_SUBSCRIPTION_ID="your-subscription-id"
AZURE_LOCATION="canadacentral"
TARGET_AZURE_FOUNDRY_REGION="canadaeast"

# Landing zone resources (provided by your org)
RG_NETWORKING="your-networking-rg"
VNET_SPOKE="your-vnet-name"

# PoC resource group (will be created)
RG_AZURE_FILES="rg-ag-pssg-azure-files-azure-foundry"

# Resource names (customize as needed)
STORAGE_ACCOUNT="stagpssgazurepocdev01"
KEYVAULT_NAME="kv-ag-pssg-azure-files"
FOUNDRY_NAME="foundry-ag-pssg-azure-files"
VM_NAME="vm-ag-pssg-azure-files-01"
```

### 3. Azure CLI Setup
```bash
# Login to Azure
az login

# Set subscription
az account set --subscription $AZURE_SUBSCRIPTION_ID

# Verify login
az account show --output table
```

## SSH Key Creation

**BC Gov Policy:** SSH keys must have passphrases for security.

### Option 1: Create New SSH Key
```powershell
# Create SSH key with passphrase
ssh-keygen -t rsa -b 4096 -C "azure-vm" -f "$env:USERPROFILE\.ssh\id_rsa_azure"

# When prompted:
# - Enter passphrase (required by BC Gov policy)
# - Confirm passphrase
```

### Option 2: Use Existing Key
If you already have an SSH key, ensure it has a passphrase:
```powershell
# Check if key exists
Test-Path "$env:USERPROFILE\.ssh\id_rsa.pub"

# If needed, add/change passphrase
ssh-keygen -p -f "$env:USERPROFILE\.ssh\id_rsa"
```

### Copy Public Key for VM Deployment
```powershell
# Display public key (copy this output)
Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
```

## Phase 1: Foundation (Network & Security)

Deploy network security groups and subnets in the landing zone VNet.

### Deploy Network Security Groups
```powershell
cd scripts\bicep

# Deploy all NSGs at once
.\deploy-nsgs.ps1

# Or deploy individually:
.\deploy-nsg-vm.ps1
.\deploy-nsg-bastion.ps1
# PE NSG deployed manually via az command
```

### Deploy Subnets
```powershell
# Deploy all subnets
.\deploy-subnet-all.ps1

# Or deploy individually:
.\deploy-subnet-vm.ps1
.\deploy-subnet-bastion.ps1
.\deploy-subnet-pe.ps1
```

### Validation
```powershell
# Check subnets exist
az network vnet subnet list --resource-group $RG_NETWORKING --vnet-name $VNET_SPOKE --output table

# Check NSGs exist
az network nsg list --resource-group $RG_AZURE_FILES --output table
```

## Phase 2: Storage, Security & Monitoring

Deploy core infrastructure services.

### Storage Account
```powershell
.\deploy-storage.ps1
```
**Purpose:** Stores AI model artifacts, scripts, datasets
**Network Access:** Configured for VPN/private access only

### Key Vault
```powershell
.\deploy-keyvault.ps1
```
**Purpose:** Manages secrets, API keys, connection strings
**Security:** Public network access disabled (BC Gov policy)

### User Assigned Managed Identity
```powershell
.\deploy-uami.ps1
```
**Purpose:** Enables passwordless authentication from VM to services
**Permissions:** Will be assigned RBAC roles to Storage, Key Vault, Foundry

### Log Analytics Workspace
```powershell
.\deploy-law.ps1
```
**Purpose:** Centralized logging and monitoring
**Retention:** 30 days configured

### Validation
```powershell
# Check all resources exist
az storage account show --name $STORAGE_ACCOUNT --resource-group $RG_AZURE_FILES
az keyvault show --name $KEYVAULT_NAME --resource-group $RG_AZURE_FILES
az identity show --name $UAMI_NAME --resource-group $RG_AZURE_FILES
az monitor workspace show --name $LAW_NAME --resource-group $RG_AZURE_FILES
```

## Phase 3: Compute Resources

Deploy the VM and Bastion for secure access.

### Virtual Machine
```powershell
.\deploy-vm-lz.ps1
```
**Requirements:**
- SSH public key (from earlier step)
- User Assigned Managed Identity (from Phase 2)
- Ubuntu 24.04 LTS with Azure extensions

### Bastion Host
```powershell
.\deploy-bastion.ps1
```
**Purpose:** Secure RDP/SSH access to VM without public IPs
**Access:** Via Azure Portal or Azure CLI

### Validation
```powershell
# Check VM status
az vm show --name $VM_NAME --resource-group $RG_AZURE_FILES --query "provisioningState"

# Check Bastion status
az network bastion show --name $BASTION_NAME --resource-group $RG_AZURE_FILES --query "provisioningState"

# Get Bastion public IP and DNS
az network bastion show --name $BASTION_NAME --resource-group $RG_AZURE_FILES --query "{dns:dnsName, ip:ipConfigurations[0].publicIpAddress.id}"
```

## Phase 4: AI Services (Azure AI Foundry)

Deploy Azure AI Foundry workspace and project.

### AI Foundry Workspace (Hub)
```powershell
.\deploy-foundry.ps1
```
**Region:** canadaeast (for LLM availability)
**Requirements:** Storage Account (from Phase 2)
**Optional:** Key Vault, User Assigned Managed Identity

### AI Foundry Project
```powershell
.\deploy-foundry-project.ps1
```
**Purpose:** Container for AI models and endpoints
**Parent:** References the Foundry Hub workspace

### Validation
```powershell
# Check Foundry workspace
az ml workspace show --name $FOUNDRY_NAME --resource-group $RG_AZURE_FILES

# Check Foundry project
az ml workspace list --resource-group $RG_AZURE_FILES --query "[?kind=='Project']"

# Get Azure AI Studio URL
Write-Host "Azure AI Studio: https://ai.azure.com/"
```

## Phase 5: Private Connectivity

Deploy private endpoints for secure, private access to all services.

### Deploy All Private Endpoints
```powershell
.\deploy-private-endpoints.ps1
```

**Private Endpoints Created:**
1. **Storage Account** (blob subresource) - canadacentral
2. **Key Vault** (vault subresource) - canadacentral
3. **Azure AI Foundry** (amlworkspace subresource) - Cross-region (canadacentral → canadaeast)

### Skip Individual Endpoints (if needed)
```powershell
# Skip storage PE
.\deploy-private-endpoints.ps1 -SkipStorage

# Skip Key Vault PE
.\deploy-private-endpoints.ps1 -SkipKeyVault

# Skip Foundry PE
.\deploy-private-endpoints.ps1 -SkipFoundry
```

### Validation
```powershell
# List all private endpoints
az network private-endpoint list --resource-group $RG_AZURE_FILES --query "[].{Name:name, Type:type, State:properties.provisioningState}" -o table

# Check provisioning states (should be 'Succeeded')
az network private-endpoint list --resource-group $RG_AZURE_FILES --query "[].properties.provisioningState" -o tsv
```

## Validation & Testing

### 1. Connect to VM via Bastion
```powershell
# SSH to VM using Bastion
az network bastion ssh `
  --name $BASTION_NAME `
  --resource-group $RG_AZURE_FILES `
  --target-resource-id $(az vm show --name $VM_NAME --resource-group $RG_AZURE_FILES --query id -o tsv) `
  --auth-type ssh-key `
  --username azureuser `
  --ssh-key "$env:USERPROFILE\.ssh\id_rsa"
```

### 2. Test DNS Resolution
From VM, verify private DNS resolution:
```bash
# Storage (should return 10.x.x.x)
nslookup stagpssgazurepocdev01.blob.core.windows.net

# Key Vault (should return 10.x.x.x)
nslookup kv-ag-pssg-azure-files.vault.azure.net

# Foundry (should return 10.x.x.x)
nslookup canadaeast.api.azureml.ms
```

### 3. Test Service Access
From VM, test access to services:
```bash
# Storage access (should work without internet)
az storage blob list --account-name stagpssgazurepocdev01 --container-name test

# Key Vault access
az keyvault secret list --vault-name kv-ag-pssg-azure-files

# Foundry API access
curl -H "Authorization: Bearer $(az account get-access-token --resource https://management.azure.com --query accessToken -o tsv)" \
  https://canadaeast.api.azureml.ms/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RG_AZURE_FILES/providers/Microsoft.MachineLearningServices/workspaces/$FOUNDRY_NAME?api-version=2023-10-01
```

### 4. Azure AI Studio Access
1. Open https://ai.azure.com/
2. Select your Foundry workspace
3. Deploy AI models to your project
4. Test model consumption from VM

## Troubleshooting

### Common Issues

#### 1. Azure Policy Blocks Private DNS Zones
**Error:** "Resource 'privatelink.*' was disallowed by policy"
**Solution:** Private DNS zones are managed centrally. The Bicep templates reference existing zones.

#### 2. SSH Connection Fails
**Error:** "Permission denied" or connection timeout
**Solutions:**
- Verify SSH key is correct: `az vm show --name $VM_NAME --resource-group $RG_AZURE_FILES --query "osProfile.linuxConfiguration.ssh.publicKeys[].keyData"`
- Update SSH key if needed: `az vm user update --resource-group $RG_AZURE_FILES --name $VM_NAME --username azureuser --ssh-key-value "$(Get-Content ~/.ssh/id_rsa.pub)"`

#### 3. Private Endpoint Provisioning Stuck
**Error:** Private endpoint shows "Updating" indefinitely
**Solution:** Check Azure Policy compliance and network security rules

#### 4. DNS Resolution Fails
**Error:** nslookup returns public IPs instead of private
**Solutions:**
- Verify private DNS zone links exist
- Check VNet DNS configuration
- Wait 10-15 minutes for DNS propagation

#### 5. Azure CLI Extension Issues
**Error:** "az ml: command not found"
**Solution:**
```bash
# Clear and reinstall ML extension
az extension remove -n ml
az extension add -n ml --debug
```

### Resource Inventory Script
Run the inventory script to verify all resources:
```powershell
cd scripts
.\azure-inventory.ps1
```

## Teardown & Cleanup

**Important:** Teardown in reverse order of deployment (Phase 5 → 4 → 3 → 2 → 1)

### Phase 5 Teardown
```powershell
# Remove private endpoints
.\teardown-private-endpoints.ps1
```

### Phase 4 Teardown
```powershell
# Remove AI services
.\teardown-foundry-project.ps1
.\teardown-foundry.ps1
```

### Phase 3 Teardown
```powershell
# Remove compute resources
.\teardown-bastion.ps1
.\teardown-vm-lz.ps1
```

### Phase 2 Teardown
```powershell
# Remove storage and security
.\teardown-law.ps1
.\teardown-uami.ps1
.\teardown-keyvault.ps1
.\teardown-storage.ps1
```

### Phase 1 Teardown
```powershell
# Remove network resources
.\teardown-subnet-pe.ps1
.\teardown-subnet-bastion.ps1
.\teardown-subnet-vm.ps1
.\teardown-nsgs.ps1
```

### Master Teardown (Alternative)
```powershell
# Orchestrated teardown (when available)
.\teardown-all.ps1
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure Landing Zone                       │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 canadacentral Region                    │  │
│  │  ┌─────────────────────────────────────────────────────┐  │
│  │  │              VNet (10.46.73.0/24)                  │  │
│  │  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  │         VM Subnet (10.46.73.0/28)              │  │  │
│  │  │  │  ┌─────────────────────────────────────────────┐  │  │  │
│  │  │  │  │         Virtual Machine                     │  │  │  │
│  │  │  │  │  • Ubuntu 24.04 LTS                         │  │  │  │
│  │  │  │  │  • Managed Identity                         │  │  │  │
│  │  │  │  │  • Runs AI consumption scripts              │  │  │  │
│  │  │  │  └─────────────────────────────────────────────┘  │  │  │
│  │  │  └─────────────────────────────────────────────────┘  │  │  │
│  │  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  │      Bastion Subnet (10.46.73.64/26)           │  │  │
│  │  │  │  ┌─────────────────────────────────────────────┐  │  │  │
│  │  │  │  │         Bastion Host                        │  │  │  │
│  │  │  │  │  • Secure SSH/RDP access                    │  │  │  │
│  │  │  │  │  • No public IPs on VM                      │  │  │  │
│  │  │  │  └─────────────────────────────────────────────┘  │  │  │
│  │  │  └─────────────────────────────────────────────────┘  │  │  │
│  │  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  │   Private Endpoints Subnet (10.46.73.128/27)   │  │  │
│  │  │  │  ┌─────────────────────────────────────────────┐  │  │  │
│  │  │  │  │     Private Endpoints                       │  │  │  │
│  │  │  │  │  • Storage PE (blob)                        │  │  │  │
│  │  │  │  │  • Key Vault PE (vault)                     │  │  │  │
│  │  │  │  │  • Foundry PE (amlworkspace)                │  │  │  │
│  │  │  │  └─────────────────────────────────────────────┘  │  │  │
│  │  │  └─────────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  │                                                         │  │
│  │  Storage Account • Key Vault • Log Analytics           │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                 canadaeast Region                       │  │
│  │  ┌─────────────────────────────────────────────────────┐  │
│  │  │         Azure AI Foundry Workspace                  │  │
│  │  │  • Hub workspace for AI Studio                      │  │
│  │  │  • Project for model deployment                     │  │
│  │  │  • Cross-region private endpoint                    │  │
│  │  └─────────────────────────────────────────────────────┘  │
│  └─────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Key Benefits

1. **Zero-Trust Security:** All access is private, no internet exposure
2. **Scalable Architecture:** Follows Azure landing zone best practices
3. **Cost Optimization:** Pay only for consumed AI resources
4. **Compliance:** Meets BC Gov security and networking requirements
5. **Maintainable:** Infrastructure as Code with Bicep templates

## Next Steps

1. **Deploy AI Models:** Use Azure AI Studio to deploy models to your Foundry project
2. **Develop Scripts:** Create AI consumption scripts on the VM
3. **Monitor Usage:** Set up alerts and monitoring in Log Analytics
4. **Scale Resources:** Adjust VM size, storage, or add more projects as needed

For questions or issues, refer to the troubleshooting section or check the Azure documentation links throughout this guide.