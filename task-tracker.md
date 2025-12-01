# Azure AI Foundry Landing Zone Deployment Task Tracker

This document tracks the progress of deploying Azure infrastructure to support **Azure AI Foundry** services with secure access via Bastion. The end goal is to run AI model consumption scripts from a VM that securely connects to AI Foundry APIs through private endpoints.

## Quick Reference

- **Deployment Manual**: See `docs\deployment-scripts-manual.md` for comprehensive guide
- **Inventory Script**: Run `scripts\azure-inventory.ps1` to list all Azure resources
- **Environment Config**: Copy `azure.env.template` to `azure.env` and fill in your values (gitignored) 


## Landing Zone Resources (Provided - Not Managed by PoC)

**IMPORTANT:** These resources are provided by the Azure landing zone and are not created or removed by PoC automation.

- [x] Azure Subscription (`$AZURE_SUBSCRIPTION_ID` in azure.env)
- [x] Azure Location (`$AZURE_LOCATION` / `$TARGET_AZURE_REGION` in azure.env)
- [x] VNet Spoke (`$VNET_SPOKE` with address space `$VNET_SPOKE_ADDRESS_SPACE`)
- [x] Resource Groups (Landing Zone)
  - Networking RG (`$RG_NETWORKING`)
  - Network Watcher RG (`$RG_NETWORK_WATCHER`)
  - ASC Export RG (`$RG_LZ_ASC_EXPORT`)

## Deployment Phases

### Phase 1: Foundation (Network & Security Perimeter) ✅ COMPLETE
- [x] Resource Group for PoC (`$RG_AZURE_FILES`) - Exists in subscription
- [x] Network Security Groups (NSGs)
  - [x] VM NSG (`$NSG_VM`) - `scripts\bicep\deploy-nsg-vm.ps1`
  - [x] Bastion NSG (`$NSG_BASTION`) - `scripts\bicep\deploy-nsg-bastion.ps1`
  - [x] Private Endpoints NSG (`$NSG_PE`) - manually via az command see `scripts\bicep\deploy-nsg-pe.ps1`
- [x] Subnets in Landing Zone VNet (`$VNET_SPOKE`)
  - [x] VM Subnet (`$SUBNET_VM` / `$SUBNET_VM_PREFIX`) - `scripts\bicep\deploy-subnet-vm.ps1`
  - [x] Bastion Subnet (`$SUBNET_BASTION` / `$SUBNET_BASTION_PREFIX`) - `scripts\bicep\deploy-subnet-bastion.ps1`
  - [x] Private Endpoints Subnet (`$SUBNET_PE` / `$SUBNET_PE_PREFIX`) - Manual az command (script fixed)

### Phase 2: Storage, Security & Monitoring (Data Plane Foundation) ✅ COMPLETE
**Dependencies:** Phase 1 complete

- [x] **Storage Account** (`$STORAGE_ACCOUNT`) - `scripts\bicep\deploy-storage.ps1` ✅
  - Stores AI model artifacts, scripts, datasets
  - Required for: Private Endpoints, AI Foundry
  - ✅ **Network Access**: VPN IP ranges configured in `networkAcls.ipRules`
  - 🔐 **SAS Tokens**: Generate via Azure Portal or `az storage container generate-sas` for secure access
  
- [x] **Key Vault** (`$KEYVAULT_NAME`) - `scripts\bicep\deploy-keyvault.ps1` ✅
  - Manages secrets, API keys, connection strings
  - Required for: VM access, AI Foundry authentication
  - ⚠️ **Access**: Public network disabled (BC Gov policy), requires Private Endpoint (Phase 4)
  
- [x] **User Assigned Managed Identity** (`$UAMI_NAME`) - `scripts\bicep\deploy-uami.ps1` ✅
  - Enables passwordless authentication for VM → Storage/Key Vault/Foundry
  - Required for: VM deployment, Private Endpoints
  - 🔑 **Principal ID**: Use for RBAC assignments to Storage/Key Vault/Foundry
  
- [x] **Log Analytics Workspace** (`$LAW_NAME`) - `scripts\bicep\deploy-law.ps1` ✅
  - Centralized logging and diagnostics
  - Required for: Monitoring all resources
  - 📊 **30-day retention**: Configure diagnostic settings for all resources

### Phase 3: Compute Resources (Execution Environment) ✅ COMPLETE
**Dependencies:** Phase 2 complete (especially UAMI, Key Vault)

- [x] **Virtual Machine** (`$VM_NAME`) - `scripts\bicep\deploy-vm-lz.ps1` ✅ DEPLOYED
  - Ubuntu 24.04 LTS VM to run AI consumption scripts
  - Uses System + User-Assigned Managed Identity for passwordless auth
  - No public IP (private subnet only)
  - 📋 **Extensions**: Azure Monitor Agent (AMA) ✅, Azure Policy ✅, MDE disabled (PoC)
  - 🔑 **SSH Access**: Requires SSH public key, connect via Bastion or VPN
  - ✅ **Status**: Provisioning succeeded, all extensions installed
  
- [x] **Bastion Host** (`$BASTION_NAME`) - `scripts\bicep\deploy-bastion.ps1` ✅ DEPLOYED
  - Secure RDP/SSH access to VM (no public IPs needed)
  - Public IP: 4.205.202.195
  - DNS: bst-a38a713d-0edb-42c3-9f39-54904e3b0316.bastion.azure.com
  - ✅ **Status**: Provisioning succeeded, ready for VM access

### Phase 4: Private Connectivity (Zero-Trust Networking) ⏳ PENDING
**Dependencies:** Phase 2 (Storage, Key Vault), Phase 1 (PE Subnet), Phase 5 (Foundry for PE_FOUNDRY)

- [ ] **Private Endpoints** - `scripts\bicep\deploy-private-endpoints.ps1`
  - PE for Storage Account (`$PE_STORAGE`) - canadacentral
  - PE for Key Vault (`$PE_KEYVAULT`) - canadacentral
  - PE for Foundry (`$PE_FOUNDRY`) - **Cross-region**: PE in canadacentral subnet → Foundry in canadaeast
  - Enables private, secure access from VM without internet exposure
  - 🌐 **Cross-Region Pattern**: Foundry PE follows BC Gov OpenAI standard - PE deployed in canadacentral connects to Foundry resource in canadaeast

### Phase 5: AI Services (Azure AI Foundry) ⏳ PENDING
**Dependencies:** Phase 2 (Storage, Key Vault, UAMI)

- [ ] **AI Foundry Workspace** (`$FOUNDRY_NAME`) - `scripts\bicep\deploy-foundry.ps1`
  - 🌐 **Region**: Deploy in **canadaeast** (`$TARGET_AZURE_FOUNDRY_REGION`) - LLMs only available in this region
  - Azure AI Studio workspace for model hosting
  - Connects to Storage for artifacts, Key Vault for secrets
  - Uses UAMI for authentication
  - ⚠️ **Important**: Deploy Foundry BEFORE creating its Private Endpoint (Phase 4)
  
- [ ] **AI Foundry Project** (`$FOUNDRY_PROJECT`) - `scripts\bicep\deploy-foundry-project.ps1`
  - Project container for AI models and endpoints
  - Where your API-accessible models will be deployed
  
- [ ] **Private Endpoint for Foundry** (created in Phase 4 after Foundry exists)
  - PE resource location: canadacentral (in `$SUBNET_PE`)
  - PE target: Foundry workspace in canadaeast
  - Pattern: Cross-region PE connection (matches BC Gov OpenAI projects)

## Deployment Workflow (Recommended Order)

### ✅ Phase 1 Complete - Foundation deployed

### 🔄 Phase 2 - Deploy Now (Storage & Security)

```powershell
cd c:\Users\RICHFREM\source\repos\AzureFilesPoC\scripts\bicep

# Storage foundation for AI artifacts
.\deploy-storage.ps1

# Security and identity
.\deploy-keyvault.ps1
.\deploy-uami.ps1

# Monitoring infrastructure
.\deploy-law.ps1
```

### ⏳ Phase 3 - Compute (After Phase 2)

```powershell
# VM for running AI scripts (requires UAMI)
.\deploy-vm-lz.ps1

# Bastion for secure access (requires Bastion subnet from Phase 1)
.\deploy-bastion.ps1
```

### ⏳ Phase 4 - Private Connectivity (After Phase 2)

```powershell
# Private endpoints for Storage and Key Vault (requires PE subnet from Phase 1)
.\deploy-private-endpoints.ps1
```

### ⏳ Phase 5 - AI Foundry (After Phase 2 & 4)

```powershell
# AI Foundry workspace and project
.\deploy-foundry.ps1
.\deploy-foundry-project.ps1
```

### 🔍 Validation

```powershell
# Verify all resources deployed
cd c:\Users\RICHFREM\source\repos\AzureFilesPoC\scripts
.\azure-inventory.ps1
```

## End State Architecture

Once complete, you'll have:

1. **VM in VM Subnet** → Runs your AI consumption scripts
2. **Bastion** → Secure RDP/SSH to VM (no public IPs)
3. **Private Endpoints** → VM accesses Storage/Key Vault/Foundry privately (no internet)
4. **AI Foundry** → Hosts AI models with API endpoints
5. **Storage** → Stores scripts, datasets, model artifacts
6. **Key Vault** → Manages API keys and secrets
7. **Managed Identity** → Passwordless auth from VM to all services

## Notes
- All Bicep templates are located in the `bicep/` directory
- All deployment scripts are in `scripts\bicep/`
- Environment variables are defined in `azure.env`
- IP subnet diagram is available in `docs\ip-subnet-diagram.md`
- Ensure Azure CLI is logged in and subscription is set before running scripts
- Scripts use idempotent operations where possible (check for existing resources)

## Cleanup and Teardown Scripts

**Teardown Order:** Reverse of deployment phases (Phase 5 → 4 → 3 → 2 → 1)

### Phase 5 Teardown (AI Services)
1. [ ] `teardown-foundry-project.ps1` - Remove Foundry Project
2. [ ] `teardown-foundry.ps1` - Remove Foundry Workspace

### Phase 4 Teardown (Private Connectivity)
3. [ ] `teardown-private-endpoints.ps1` - Remove Private Endpoints (Storage, Key Vault, Foundry)

### Phase 3 Teardown (Compute)
4. [x] `teardown-bastion.ps1` - Remove Bastion Host, Public IP ✅
5. [x] `teardown-vm-lz.ps1` - Remove VM, NICs, NSGs, Disks ✅

### Phase 2 Teardown (Storage & Security)
6. [x] `teardown-law.ps1` - Remove Log Analytics Workspace ✅
7. [x] `teardown-uami.ps1` - Remove Managed Identity ✅
8. [x] `teardown-keyvault.ps1` - Remove Key Vault (soft-delete + purge option) ✅
9. [x] `teardown-storage.ps1` - Remove Storage Account ✅

### Phase 1 Teardown (Foundation)
10. [x] `teardown-subnet-pe.ps1` - Remove PE Subnet (EXISTS)
11. [x] `teardown-subnet-bastion.ps1` - Remove Bastion Subnet ✅
12. [x] `teardown-subnet-vm.ps1` - Remove VM Subnet ✅
13. [x] `teardown-nsgs.ps1` - Remove all NSGs (VM, Bastion, PE) ✅

### Master Teardown
- [ ] `teardown-all.ps1` - Master orchestration script
  - Reverse phase order (5→4→3→2→1)
  - Confirmation prompts per phase
  - Parallel teardown within phases where safe
  - Error handling and logging
  - Idempotent (skip missing resources)