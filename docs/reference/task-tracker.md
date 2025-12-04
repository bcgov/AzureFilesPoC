# Azure AI Foundry Landing Zone Deployment Task Tracker

This document tracks the progress of deploying Azure infrastructure to support **Azure AI Foundry** services with secure access via Bastion. The end goal is to run AI model consumption scripts from a VM that securely connects to AI Foundry APIs through private endpoints.

## Quick Reference

- **Documentation Index**: See [`../README.md`](../README.md) for all documentation
- **Deployment Guide**: See [`../guides/deployment-guide.md`](../guides/deployment-guide.md) for step-by-step instructions
- **AI Model Testing**: See [`../guides/ai-model-testing.md`](../guides/ai-model-testing.md) for model deployment & testing
- **Inventory Script**: Run `scripts/azure-inventory.ps1` to list all Azure resources
- **Environment Config**: Copy `azure.env.template` to `azure.env` and fill in your values (gitignored)
- **Archived CI/CD**: See `scripts/ARCHIVE/` for Terraform and GitHub Actions code (not currently used) 


## Resource Inventory

| Resource Type                        | Resource Name / Variable         | Region         | Notes                                      |
|--------------------------------------|----------------------------------|---------------|--------------------------------------------|
| **Resource Group**                   | `rg-azurefiles-poc`              | canadacentral | Main PoC resource group                    |
| **Virtual Network (VNet)**           | `vnet-spoke`                     | canadacentral | Provided by landing zone                   |
| **Subnet - VM**                      | `subnet-vm`                      | canadacentral | For VM                                     |
| **Subnet - Bastion**                 | `subnet-bastion`                 | canadacentral | For Bastion                                |
| **Subnet - Private Endpoints**       | `subnet-pe`                      | canadacentral | For all Private Endpoints                  |
| **Network Security Group - VM**      | `nsg-vm`                         | canadacentral | For VM subnet                              |
| **Network Security Group - Bastion** | `nsg-bastion`                    | canadacentral | For Bastion subnet                         |
| **Network Security Group - PE**      | `nsg-pe`                         | canadacentral | For PE subnet                              |
| **Storage Account**                  | `stazurefilespoc`                | canadacentral | Stores artifacts, scripts, datasets        |
| **Key Vault**                        | `kv-azurefiles-poc`              | canadacentral | Secrets, keys, connection strings          |
| **User Assigned Managed Identity**   | `uami-azurefiles-poc`            | canadacentral | Passwordless auth for VM                   |
| **Log Analytics Workspace**          | `law-azurefiles-poc`             | canadacentral | Centralized logging                        |
| **Virtual Machine**                  | `vm-azurefiles-poc`              | canadacentral | Ubuntu 24.04 LTS, no public IP             |
| **Bastion Host**                     | `bastion-azurefiles-poc`         | canadacentral | Secure SSH/RDP to VM                       |
| **Private Endpoint - Storage**       | `pe-storage-azurefilespoc`       | canadacentral | PE to Storage Account                      |
| **Private Endpoint - Key Vault**     | `pe-keyvault-azurefilespoc`      | canadacentral | PE to Key Vault                            |
| **Private Endpoint - Foundry**       | `pe-foundry-azurefilespoc`       | canadacentral | Cross-region PE to Foundry in canadaeast    |
| **AI Foundry Workspace**             | `foundry-azurefiles-poc`         | canadaeast    | AI Studio workspace (canadaeast)           |
| **AI Foundry Project**               | `foundryproj-azurefiles-poc`     | canadaeast    | Project container for models               |

**Legend:**  
- canadacentral = Primary region for PoC resources  
- canadaeast = Region for Azure AI Foundry services  
- All names are examples; use your actual resource names if different  
- Landing Zone resources are provided, not managed by PoC automation  
- All names/variables are defined in `azure.env`


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
  - ⚠️ **OPTIONAL for Foundry**: Foundry can auto-create Key Vault if not provided
  - Recommended for: Explicit control over secrets, VM access, audit requirements
  - ⚠️ **Access**: Public network disabled (BC Gov policy), requires Private Endpoint (Phase 5)
  
- [x] **User Assigned Managed Identity** (`$UAMI_NAME`) - `scripts\bicep\deploy-uami.ps1` ✅
  - Enables passwordless authentication for VM → Storage/Key Vault/Foundry
  - ⚠️ **OPTIONAL for Foundry**: Foundry can use system-assigned identity instead
  - Recommended for: Consistent identity across VM and Foundry, granular RBAC control
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

### Phase 4: AI Services (Azure AI Foundry) ✅ COMPLETE
**Dependencies:** Phase 2 (Storage Account REQUIRED, Key Vault OPTIONAL, UAMI OPTIONAL)

- [x] **AI Foundry Workspace** (`$FOUNDRY_NAME`) - `scripts\bicep\deploy-foundry.ps1` ✅ DEPLOYED
  - 🌐 **Region**: Deployed in **canadaeast** (`$TARGET_AZURE_FOUNDRY_REGION`) - LLMs available in this region
  - Azure AI Studio workspace for model hosting
  - ✅ **Required**: Storage Account for artifacts (stagpssgazurepocdev01)
  - ⚠️ **Optional**: Key Vault (Foundry auto-created workspace KV), UAMI (uses system-assigned identity)
  - 💡 **Recommendation**: Used existing Storage Account, let Foundry auto-create Key Vault & App Insights
  - ⚠️ **Important**: Deploy Foundry BEFORE creating its Private Endpoint (Phase 5)
  - ✅ **Status**: Provisioning succeeded, Discovery URL: https://canadaeast.api.azureml.ms/discovery
  
- [x] **AI Foundry Project** (`$FOUNDRY_PROJECT`) - `scripts\bicep\deploy-foundry-project.ps1` ✅ DEPLOYED
  - Project container for AI models and endpoints
  - Where your API-accessible models will be deployed
  - ✅ **Status**: Provisioning succeeded, Workspace ID: 3bbe6d98-be5b-4879-a97f-59d14f8c6717
  - ✅ **Parent Hub**: Connected to foundry-ag-pssg-azure-files (hubResourceId reference)

### Phase 5: Private Connectivity (Zero-Trust Networking) ✅ COMPLETE
**Dependencies:** Phase 2 (Storage, Key Vault), Phase 4 (Foundry), Phase 1 (PE Subnet)

- [x] **All Private Endpoints** - `scripts\bicep\deploy-private-endpoints.ps1` ✅ DEPLOYED
  - [x] PE for Storage Account (`$PE_STORAGE`) - canadacentral → blob subresource
  - [x] PE for Key Vault (`$PE_KEYVAULT`) - canadacentral → vault subresource  
  - [x] PE for Foundry (`$PE_FOUNDRY`) - **Cross-region**: PE in canadacentral → Foundry in canadaeast
  - ⚠️ **Deploy after Phase 4** - Requires all target resources (Storage, Key Vault, Foundry) to exist
  - Enables private, secure access from VM without internet exposure
  - 🌐 **Cross-Region Pattern**: Foundry PE follows BC Gov OpenAI standard
  - 💡 **Benefit**: Test resources work first, then lock down with private connectivity
  - ✅ **Scripts Enhanced**: Added comprehensive verification instructions and improved parsing
  - ✅ **Bicep Templates Updated**: Policy-compliant, reference existing DNS zones
  - ✅ **Status**: All private endpoints deployed successfully, DNS resolution verified

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

### ⏳ Phase 4 - AI Foundry (After Phase 2) ✅ COMPLETE

```powershell
# AI Foundry workspace and project
.\deploy-foundry.ps1
.\deploy-foundry-project.ps1
```

### ⏳ Phase 5 - Private Endpoints (After Phase 4) ✅ COMPLETE

```powershell
# Deploy all private endpoints (Storage, Key Vault, Foundry)
.\deploy-private-endpoints.ps1
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

## Comprehensive Deployment Guide

✅ **Complete Deployment Guide Created**: `docs\azure-ai-foundry-deployment-guide.md`

This comprehensive guide includes:
- Prerequisites and environment setup
- SSH key creation and VM access procedures
- Phase-by-phase deployment instructions with commands
- Validation and testing procedures for each phase
- Troubleshooting common issues
- Complete resource inventory and cleanup procedures
- Architecture diagrams and explanations
- Security considerations and best practices

**Next Steps:**
1. **✅ Phase 5 Complete**: All private endpoints deployed and verified operational
2. **Test End-to-End**: Connect to VM via Bastion and test all private connectivity
3. **Deploy AI Models**: Use Azure AI Studio to deploy models to your Foundry project
4. **Monitor & Maintain**: Use Log Analytics Workspace for monitoring and alerting

## Cleanup and Teardown Scripts

**Teardown Order:** Reverse of deployment phases (Phase 5 → 4 → 3 → 2 → 1)

### Quick Teardown (Recommended)
```powershell
cd scripts\bicep
.\teardown-all.ps1  # Interactive master teardown with confirmations
.\teardown-all.ps1 -Force  # Non-interactive teardown (dangerous!)
```

### Manual Teardown (Individual Scripts)
**⚠️ WARNING**: Use individual scripts only if master teardown fails. Order is critical!

### Phase 5 Teardown (Private Connectivity)
1. [x] `teardown-private-endpoints.ps1` - Remove Private Endpoints (Storage, Key Vault, Foundry) ✅ CREATED

### Phase 4 Teardown (AI Services)
2. [x] `teardown-foundry-project.ps1` - Remove Foundry Project ✅
3. [x] `teardown-foundry.ps1` - Remove Foundry Workspace ✅

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
- [x] `teardown-all.ps1` - Master orchestration script ✅ CREATED
  - Reverse phase order (5→4→3→2→1)
  - Confirmation prompts per phase
  - Parallel teardown within phases where safe
  - Error handling and logging
  - Idempotent (skip missing resources)