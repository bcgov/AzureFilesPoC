# Complete Guide: Azure AI Foundry "Hello World" Model Test

This guide provides step-by-step instructions to deploy the complete Azure infrastructure and perform a "Hello World" test with an AI model using Azure AI Foundry.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Infrastructure Deployment](#infrastructure-deployment)
4. [Bastion Connection Setup](#bastion-connection-setup)
5. [AI Model Deployment](#ai-model-deployment)
6. [Model Testing](#model-testing)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software
- **Azure CLI** (`az`): `winget install Microsoft.AzureCLI` or download from [azure.microsoft.com]
- **Azure PowerShell** (optional): `Install-Module -Name Az -AllowClobber -Scope CurrentUser`
- **Git**: For cloning this repository
- **SSH Client**: Built-in Windows SSH or PuTTY

### Azure Requirements
- **Azure Subscription**: With permissions to create resources
- **Landing Zone Access**: Pre-existing VNet and subnets in canadacentral region
- **User Permissions**: Contributor access to subscription/resource groups

### Repository Setup
```bash
# Clone the repository
git clone https://github.com/bcgov/AzureFilesPoC.git
cd AzureFilesPoC

# Copy environment template
cp azure.env.template azure.env
# Edit azure.env with your actual values
```

## Environment Setup

### 1. Configure Azure Environment Variables

Edit `azure.env` with your actual Azure resource names:

```bash
# Required variables to update:
AZURE_SUBSCRIPTION_ID="your-subscription-id"
RG_AZURE_FILES="your-resource-group-name"
VNET_SPOKE="your-vnet-name"
RG_NETWORKING="your-networking-rg"

# Keep default values for PoC resources unless you have specific naming requirements
```

### 2. Azure CLI Authentication

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription $AZURE_SUBSCRIPTION_ID

# Verify login
az account show --output table
```

### 3. Load Environment Variables

```bash
# Load environment variables (run this in each new PowerShell session)
. .\azure.env
```

## Infrastructure Deployment

All infrastructure is deployed using Bicep templates in the correct dependency order.

### Phase 1: Foundation (Network & Security)

```powershell
cd scripts\bicep

# 1. Create Resource Group
.\deploy-resource-group.ps1

# 2. Deploy Network Security Groups
.\deploy-nsgs.ps1

# 3. Create Subnets
.\deploy-subnet-all.ps1
```

### Phase 2: Storage & Security Services

```powershell
# 4. Storage Account (required for AI Foundry)
.\deploy-storage.ps1

# 5. Key Vault (optional but recommended)
.\deploy-keyvault.ps1

# 6. User-Assigned Managed Identity
.\deploy-uami.ps1

# 7. Log Analytics Workspace
.\deploy-law.ps1
```

### Phase 3: Compute Resources

```powershell
# 8. Virtual Machine (Ubuntu 24.04 LTS)
.\deploy-vm-lz.ps1

# 9. Bastion Host (for secure VM access)
.\deploy-bastion.ps1
```

### Phase 4: AI Services

```powershell
# 10. AI Foundry Hub Workspace (in canadaeast region)
.\deploy-foundry.ps1

# 11. AI Foundry Project (references the hub)
.\deploy-foundry-project.ps1
```

### Phase 5: Private Connectivity

```powershell
# 12. Private Endpoints (for secure access)
.\deploy-private-endpoints.ps1
```

### Deployment Verification

After deployment, run the inventory script to verify all resources:

```powershell
cd ..\  # Back to scripts directory
.\azure-inventory.ps1
```

Check the generated `azure-inventory-summary.md` for deployment status.

## Bastion Connection Setup

### 1. Generate SSH Key Pair

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "your-email@example.com" -f ~/.ssh/azure-poc-key

# Copy public key to clipboard
cat ~/.ssh/azure-poc-key.pub
```

### 2. Add SSH Key to VM

The VM was deployed with your SSH public key. If you need to update it:

```powershell
# Get VM public key from Key Vault
az keyvault secret show --vault-name $KEYVAULT_NAME --name "vm-ssh-public-key"
```

### 3. Connect via Azure Bastion

```powershell
# Method 1: Azure CLI (recommended)
az network bastion ssh --name $BASTION_NAME --resource-group $RG_AZURE_FILES --target-resource-id "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_AZURE_FILES/providers/Microsoft.Compute/virtualMachines/$VM_NAME" --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/azure-poc-key

# Method 2: Azure Portal
# 1. Go to Bastion resource in Azure Portal
# 2. Click "Connect" > "SSH"
# 3. Upload your private key or use username/password
# 4. Connect
```

### 4. Verify VM Connection

Once connected to the VM:

```bash
# Verify you're on the VM
hostname
whoami
pwd

# Check Azure CLI installation
az --version

# Verify managed identity
az login --identity
```

## AI Model Deployment

### 1. Access Azure AI Studio

1. **Open Azure AI Studio**: https://ai.azure.com
2. **Select your subscription and resource group**
3. **Choose your AI Foundry project**: `$FOUNDRY_PROJECT`

### 2. Deploy a Model

1. **Navigate to "Models" in the left sidebar**
2. **Click "Deploy" on a base model** (e.g., GPT-4o-mini or GPT-3.5-turbo)
3. **Configure deployment**:
   - **Deployment name**: `hello-world-test`
   - **Model version**: Latest
   - **Deployment type**: Standard
   - **Virtual machine**: Smallest available (for testing)
4. **Set authentication**: Use key-based authentication
5. **Deploy the model** (this takes 10-15 minutes)

### 3. Get Endpoint Information

After deployment:
1. **Go to "Endpoints" in AI Studio**
2. **Select your deployed endpoint**
3. **Copy the following**:
   - **REST endpoint URL**
   - **Primary key** (or use Azure AD authentication)

## Model Testing

### Option 1: Test from Local Machine (via Azure CLI)

```powershell
# Navigate to scripts directory
cd scripts

# Test the deployed model
.\test-ai-model.ps1 -WorkspaceName $FOUNDRY_PROJECT -ResourceGroup $RG_AZURE_FILES -EndpointName "hello-world-test"
```

### Option 2: Test from VM (via Bastion)

1. **Connect to VM via Bastion** (see above)
2. **Install Azure CLI on VM** (if not already installed):

```bash
# On the VM
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az login --identity
```

3. **Run the test script on VM**:

```bash
# Copy test script to VM (or download from repo)
# Then run:
./test-ai-model.ps1 -WorkspaceName "$FOUNDRY_PROJECT" -ResourceGroup "$RG_AZURE_FILES" -EndpointName "hello-world-test"
```

### Option 3: Manual REST API Test

```bash
# Get endpoint details from Azure AI Studio
ENDPOINT_URL="https://your-endpoint.openai.azure.com/"
API_KEY="your-api-key"

# Test with curl
curl -X POST "$ENDPOINT_URL/openai/deployments/hello-world-test/chat/completions?api-version=2024-02-15-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: $API_KEY" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "Hello! Please respond with a simple greeting and tell me what AI model you are."
      }
    ],
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

## Expected Results

### Successful Test Output

```
Connected to Azure subscription: Your Subscription Name

Testing Azure AI Foundry workspace: foundry-project-ag-pssg
Found AI Foundry workspace: foundry-project-ag-pssg
Location: canadaeast

Testing deployed endpoint: hello-world-test
Found endpoint: hello-world-test
Provisioning state: Succeeded

Response from endpoint hello-world-test:
Hello! I'm an AI assistant powered by GPT-4o-mini. How can I help you today?

AI Model test completed successfully! 🎉
```

### What This Proves

✅ **Infrastructure Working**: All Azure resources deployed correctly
✅ **Network Connectivity**: Private endpoints allowing secure access
✅ **AI Services Operational**: Model deployment successful
✅ **Authentication Working**: API keys or managed identity functioning
✅ **End-to-End Flow**: Complete path from VM to AI model working

## Troubleshooting

### Common Issues

#### 1. Bastion Connection Fails
```bash
# Check Bastion status
az network bastion show --name $BASTION_NAME --resource-group $RG_AZURE_FILES --output table

# Verify VM is running
az vm show --name $VM_NAME --resource-group $RG_AZURE_FILES --show-details --output table
```

#### 2. Model Deployment Fails
- **Check region availability**: AI models may not be available in canadacentral
- **Verify storage account**: AI Foundry requires a storage account for artifacts
- **Check quotas**: You may need to request quota increases for GPU/CPU resources

#### 3. API Calls Fail
```bash
# Test network connectivity from VM
curl -I https://canadaeast.api.azureml.ms/

# Check private endpoint DNS resolution
nslookup your-endpoint.openai.azure.com
```

#### 4. Authentication Issues
```bash
# Test managed identity on VM
az login --identity
az account show

# Verify Key Vault access
az keyvault secret list --vault-name $KEYVAULT_NAME
```

### Logs and Diagnostics

```powershell
# Check VM logs
az monitor diagnostic-settings list --resource /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_AZURE_FILES/providers/Microsoft.Compute/virtualMachines/$VM_NAME

# AI Foundry logs
az monitor diagnostic-settings list --resource /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG_AZURE_FILES/providers/Microsoft.MachineLearningServices/workspaces/$FOUNDRY_PROJECT
```

### Getting Help

1. **Check the task tracker**: `task-tracker.md` for current deployment status
2. **Review inventory**: `azure-inventory-summary.md` for resource verification
3. **Azure Portal**: Check resource status and error messages
4. **Azure Support**: Open a ticket for deployment or service issues

## Next Steps

After successful "Hello World" testing:

1. **Deploy Production Models**: Use larger, more capable models
2. **Implement Monitoring**: Set up Azure Monitor alerts and dashboards
3. **Security Hardening**: Configure network security and access controls
4. **CI/CD Pipeline**: Automate model deployment and testing
5. **Application Integration**: Connect your applications to the AI endpoints

## Cost Considerations

- **AI Model Hosting**: Pay-per-token for API calls
- **VM Costs**: Running 24/7 for development/testing
- **Storage**: Minimal cost for model artifacts
- **Network**: Private endpoints have no additional cost

Monitor costs in Azure Cost Management and set up budgets for production use.