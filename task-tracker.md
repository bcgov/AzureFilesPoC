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
  - [x] Private Endpoints NSG (`$NSG_PE`) - `scripts\bicep\deploy-nsg-pe.ps1`
- [x] Subnets in Landing Zone VNet (`$VNET_SPOKE`)
  - [x] VM Subnet (`$SUBNET_VM` / `$SUBNET_VM_PREFIX`) - `scripts\bicep\deploy-subnet-vm.ps1`
  - [x] Bastion Subnet (`$SUBNET_BASTION` / `$SUBNET_BASTION_PREFIX`) - `scripts\bicep\deploy-subnet-bastion.ps1`
  - [x] Private Endpoints Subnet (`$SUBNET_PE` / `$SUBNET_PE_PREFIX`) - Manual az command (script fixed)

### Phase 2: Storage, Security & Monitoring (Data Plane Foundation) 🔄 NEXT
**Dependencies:** Phase 1 complete

- [x] **Storage Account** (`$STORAGE_ACCOUNT`) - `scripts\bicep\deploy-storage.ps1` ✅
  - Stores AI model artifacts, scripts, datasets
  - Required for: Private Endpoints, AI Foundry
  - ✅ **Network Access**: VPN IP ranges configured in `networkAcls.ipRules`
  - 🔐 **SAS Tokens**: Generate via Azure Portal or `az storage container generate-sas` for secure access
  
- [ ] **Key Vault** (`$KEYVAULT_NAME`) - `scripts\bicep\deploy-keyvault.ps1`
  - Manages secrets, API keys, connection strings
  - Required for: VM access, AI Foundry authentication
  
- [ ] **User Assigned Managed Identity** (`$UAMI_NAME`) - `scripts\bicep\deploy-uami.ps1`
  - Enables passwordless authentication for VM → Storage/Key Vault/Foundry
  - Required for: VM deployment, Private Endpoints
  
- [ ] **Log Analytics Workspace** (`$LAW_NAME`) - `scripts\bicep\deploy-law.ps1`
  - Centralized logging and diagnostics
  - Required for: Monitoring all resources

### Phase 3: Compute Resources (Execution Environment) ⏳ PENDING
**Dependencies:** Phase 2 complete (especially UAMI, Key Vault)

- [ ] **Virtual Machine** (`$VM_NAME`) - `scripts\bicep\deploy-vm-lz.ps1`
  - Windows/Linux VM to run AI consumption scripts
  - Uses Managed Identity to access Foundry APIs
  - No public IP (private subnet only)
  
- [ ] **Bastion Host** (`$BASTION_NAME`) - `scripts\bicep\deploy-bastion.ps1`
  - Secure RDP/SSH access to VM (no public IPs needed)
  - Includes Public IP and NIC

### Phase 4: Private Connectivity (Zero-Trust Networking) ⏳ PENDING
**Dependencies:** Phase 2 (Storage, Key Vault), Phase 1 (PE Subnet)

- [ ] **Private Endpoints** - `scripts\bicep\deploy-private-endpoints.ps1`
  - PE for Storage Account (`$PE_STORAGE`)
  - PE for Key Vault (`$PE_KEYVAULT`)
  - Enables private, secure access from VM without internet exposure

### Phase 5: AI Services (Azure AI Foundry) ⏳ PENDING
**Dependencies:** Phase 2 (Storage, Key Vault, UAMI), Phase 4 (Private Endpoints)

- [ ] **AI Foundry Workspace** (`$FOUNDRY_NAME`) - `scripts\bicep\deploy-foundry.ps1`
  - Azure AI Studio workspace for model hosting
  - Connects to Storage for artifacts, Key Vault for secrets
  
- [ ] **AI Foundry Project** (`$FOUNDRY_PROJECT`) - `scripts\bicep\deploy-foundry-project.ps1`
  - Project container for AI models and endpoints
  - Where your API-accessible models will be deployed

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
3. [ ] `teardown-private-endpoints.ps1` - Remove Private Endpoints (Storage, Key Vault)

### Phase 3 Teardown (Compute)
4. [ ] `teardown-bastion.ps1` - Remove Bastion Host (NIC, PIP)
5. [ ] `teardown-vm-lz.ps1` - Remove Virtual Machine

### Phase 2 Teardown (Storage & Security)
6. [ ] `teardown-law.ps1` - Remove Log Analytics Workspace
7. [ ] `teardown-uami.ps1` - Remove Managed Identity
8. [ ] `teardown-keyvault.ps1` - Remove Key Vault (must purge soft-delete)
9. [ ] `teardown-storage.ps1` - Remove Storage Account

### Phase 1 Teardown (Foundation)
10. [x] `teardown-subnet-pe.ps1` - Remove PE Subnet (EXISTS)
11. [ ] `teardown-subnet-bastion.ps1` - Remove Bastion Subnet
12. [ ] `teardown-subnet-vm.ps1` - Remove VM Subnet
13. [ ] `teardown-nsgs.ps1` - Remove all NSGs

### Master Teardown
- [ ] `teardown-all.ps1` - Master orchestration script
  - Reverse phase order (5→4→3→2→1)
  - Confirmation prompts per phase
  - Parallel teardown within phases where safe
  - Error handling and logging
  - Idempotent (skip missing resources)