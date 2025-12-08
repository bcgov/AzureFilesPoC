# Complete Guide: Azure AI Foundry "Hello World" Model Test

This guide provides step-by-step instructions to test an AI model in Azure AI Foundry.

> **Prerequisites:** This guide assumes you have completed the [Deployment Guide](./deployment-guide.md) and have all Azure infrastructure deployed (VM, Bastion, Azure OpenAI, private endpoints, etc.).

## Daily Operations

For day-to-day usage after initial setup:

| Task | Runbook |
|------|---------|
| **Start of day** - Start VM & Bastion | [Daily Startup Runbook](../runbooks/daily-startup.md) |
| **End of day** - Stop VM & delete Bastion | [Daily Shutdown Runbook](../runbooks/daily-shutdown.md) |
| **Transfer files** - SCP via Bastion tunnel | [SCP File Transfer Guide](../runbooks/scp-file-transfer.md) |

## Quick Reference: Scripts

| Script | Location | Purpose |
|--------|----------|---------|
| `setup-vm-env.sh` | [examples/](../../examples/setup-vm-env.sh) | One-command VM Python environment setup |
| `activate-ai-env.sh` | [examples/](../../examples/activate-ai-env.sh) | Activate venv + set Azure OpenAI env vars |
| `upload-to-blob.ps1` | [examples/](../../examples/upload-to-blob.ps1) | Upload files from local to blob storage |
| `download-from-blob.sh` | [examples/](../../examples/download-from-blob.sh) | Download files on VM via private endpoint |
| `process-blob-file.sh` | [examples/](../../examples/process-blob-file.sh) | Full pipeline: download + summarize |

## Table of Contents
1. [Prerequisites](#prerequisites) – Ensure all required tools, access, and environment variables are set up
2. [Environment Setup](#environment-setup) – Reference deployment guide for setup steps
3. [Infrastructure Deployment](#infrastructure-deployment) – Reference deployment guide for resource provisioning
4. [Bastion Connection Setup](#bastion-connection-setup) – Connect to your VM securely (see [Bastion Connection Guide](../runbooks/bastion-connection.md))
5. [AI Model Deployment](#ai-model-deployment) – Deploy a test model in Azure AI Foundry
6. [Model Testing](#model-testing) – Run a test to verify model deployment
7. [Troubleshooting](#troubleshooting) – Resolve common issues

## Prerequisites

> **Step 1: Make sure all prerequisites are in place**
> - See [Deployment Guide](./deployment-guide.md#prerequisites) for required software, Azure permissions, and environment variables.
> - Clone the repository and set up your environment file as described in the deployment guide.

## Environment Setup

> **Step 2: Configure your Azure environment**
> - Follow [Environment Setup](./deployment-guide.md#environment-setup) in the deployment guide for details on configuring environment variables and Azure CLI authentication.

## Infrastructure Deployment

> **Step 3: Deploy or verify Azure resources**
> - Use the [Deployment Guide](./deployment-guide.md#infrastructure-deployment) for step-by-step instructions on deploying all required Azure resources.
> - Run inventory scripts to verify resources as described in the deployment guide.

## Bastion Connection Setup

> **Step 4: Connect to your VM via Bastion**
> - See [Bastion Connection Guide](../runbooks/bastion-connection.md) for details on checking VM status, preparing your SSH key, and connecting securely.
> - For VM shutdown and update instructions, see [VM Shutdown](../runbooks/vm-shutdown.md) and [VM Updates](../runbooks/vm-updates.md).

## AI Model Deployment

> **Step 5: Deploy your AI model**

### Prerequisites: Azure OpenAI Resource

Before deploying models, you must have an Azure OpenAI resource with private endpoint. Azure Policy blocks public IP creation on PaaS services.

**If you haven't deployed Azure OpenAI yet:**
```powershell
# From scripts/bicep folder
.\deploy-openai.ps1
```

See [Phase 4.5: Azure OpenAI Resource](./deployment-guide.md#phase-45-azure-openai-resource) in the deployment guide for details.

### Connect Azure OpenAI to Foundry Project

1. Open [Azure AI Studio](https://ai.azure.com/) or access via Azure Portal → your Foundry resource → **Launch studio**
2. In the left navigation, under **Project (foundry-project-ag-pssg)**, click **Overview**
   - Display name: "AI Foundry Project for ag-pssg-azure-files-poc"
3. In the **Connected resources** section, click **+ New connection**
4. Search for "azure" and select **Azure OpenAI** (AI Models)
5. Your resource `openai-ag-pssg-azure-files` appears - it shows:
   - Location: canadaeast
   - Resource group: rg-ag-pssg-azure-files-azure-foundry
   - Deployments: No deployments (expected)
6. Leave Authentication as **API key**
7. Click **Add connection**
8. Wait for "Connected ✓" status, then click **Close**

### Deploy the Model

1. In the left nav under your **Project**, click **Models + endpoints**
2. Click **+ Deploy model** (blue button)
3. Search for "nano" and select **gpt-5-nano** (Chat completion, Responses)
4. Click **Confirm**
5. Configure deployment settings:
   - **Deployment name:** `gpt-5-nano` (or customize)
   - **Deployment type:** Global Standard
   - **Deployment details** (auto-populated):
     - Model version: 2025-08-07
     - AI hub: foundry-ag-pssg-azure-files
     - Resource location: Canada East
     - Capacity: 250K tokens per minute (TPM)
     - Authentication type: Key
6. Click **Deploy**
7. Wait for deployment to complete (usually 1-2 minutes)

### Verify Deployment (Azure CLI)

```powershell
# List all deployments on your Azure OpenAI resource
az cognitiveservices account deployment list `
  --name openai-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry `
  -o table

# Get deployment details (status should be "Succeeded")
az cognitiveservices account deployment show `
  --name openai-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry `
  --deployment-name gpt-5-nano `
  --query "{Name:name, Model:properties.model.name, Version:properties.model.version, Status:properties.provisioningState, Capacity:properties.currentCapacity}" `
  -o table
```

**Expected output:**
```
Name        Model       Version     Status     Capacity
----------  ----------  ----------  ---------  ----------
gpt-5-nano  gpt-5-nano  2025-08-07  Succeeded  250
```

> **Note:** All connectivity uses private endpoints. The model is deployed to your Azure OpenAI resource which has public network access disabled.

## Model Testing

> **Step 6: Test your deployed model**
> 
> **Important:** The Azure OpenAI resource has public access disabled. Testing from the AI Studio playground will show:
> ```
> 403: Public access is disabled. Please configure private endpoint.
> ```
> This is **expected behavior** - you must test from the VM via private endpoint.

### Test from VM (via Bastion)

1. **Connect to VM via Bastion** ([see connection guide](../runbooks/bastion-connection.md)):
```powershell
az network bastion ssh `
  --name bastion-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry `
  --target-resource-id "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-01" `
  --auth-type ssh-key `
  --username azureuser `
  --ssh-key ~/.ssh/id_rsa_azure
```

2. **Verify DNS resolves to private IP:**
```bash
nslookup openai-ag-pssg-azure-files.openai.azure.com
```
**Expected output:**
```
Name:   openai-ag-pssg-azure-files.privatelink.openai.azure.com
Address: 10.46.73.137  <-- Private IP confirms private endpoint is working
```

3. **Install Azure CLI on VM** (first time only):
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

4. **Login to Azure:**
```bash
# Try managed identity first (if VM has RBAC roles configured)
az login --identity

# If managed identity fails, use device code login:
az login
# Follow the instructions to open https://microsoft.com/devicelogin
# Enter the code displayed, then authenticate in your browser
```

> **Note:** If `az login --identity` fails with "No managed identity found", the VM's system-assigned 
> managed identity may not have RBAC roles configured. Use interactive device code login instead.

5. **Get API key and test the model:**
```bash
# Get API key
API_KEY=$(az cognitiveservices account keys list \
  --name openai-ag-pssg-azure-files \
  --resource-group rg-ag-pssg-azure-files-azure-foundry \
  --query key1 -o tsv)

# Test gpt-5-nano deployment (reasoning model needs more tokens)
curl -X POST "https://openai-ag-pssg-azure-files.openai.azure.com/openai/deployments/gpt-5-nano/chat/completions?api-version=2024-02-15-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: $API_KEY" \
  -d '{
    "messages": [{"role": "user", "content": "Hello! What is the capital of France?"}],
    "max_completion_tokens": 500
  }'
```

> **Note:** gpt-5-nano is a reasoning model that uses `max_completion_tokens` (not `max_tokens`).
> It reserves tokens for internal reasoning before generating the response.

**Expected response:**
```json
{
  "choices": [{
    "message": {
      "role": "assistant",
      "content": "Hi! The capital of France is Paris."
    },
    "finish_reason": "stop"
  }],
  "model": "gpt-5-nano-2025-08-07",
  "usage": {
    "completion_tokens": 147,
    "prompt_tokens": 15,
    "total_tokens": 162
  }
}
```

### Why Playground Fails but VM Works

| Access Method | Network Path | Result |
|---------------|--------------|--------|
| AI Studio Playground | Public Internet → Azure OpenAI | ❌ 403 Forbidden |
| VM via Bastion | Private Endpoint → Azure OpenAI | ✅ Success |

This confirms zero-trust security is working correctly.

---

## Advanced Testing: Document Summarization

After completing the "Hello World" test above, try more realistic scenarios using Python scripts.

### Option 1: Create Files Directly on VM (Recommended)

The simplest approach - paste commands directly in your SSH session.

**Step 1: Create the examples directory and script**

```bash
# Create directory
mkdir -p ~/examples
cd ~/examples

# Create the summarization script
cat > summarize-document.py << 'EOF'
#!/usr/bin/env python3
"""Summarize documents using Azure OpenAI via private endpoint."""
import os, sys
from openai import AzureOpenAI

def main():
    if len(sys.argv) < 2:
        print("Usage: python summarize-document.py <filename>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    endpoint = os.environ.get("AZURE_OPENAI_ENDPOINT")
    api_key = os.environ.get("AZURE_OPENAI_KEY")
    deployment = os.environ.get("AZURE_OPENAI_DEPLOYMENT", "gpt-5-nano")
    
    if not endpoint or not api_key:
        print("Error: Set AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY")
        sys.exit(1)
    
    with open(filepath, 'r') as f:
        text = f.read()
    
    print(f"Summarizing: {filepath} ({len(text)} characters)")
    print("-" * 50)
    
    client = AzureOpenAI(
        azure_endpoint=endpoint,
        api_key=api_key,
        api_version="2024-12-01-preview"
    )
    
    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "Summarize documents concisely with key points."},
            {"role": "user", "content": f"Summarize this document:\n\n{text}"}
        ],
        max_completion_tokens=500
    )
    
    print("\n📄 SUMMARY:\n")
    print(response.choices[0].message.content)
    print("\n" + "-" * 50)
    print("✅ Generated via private endpoint")

if __name__ == "__main__":
    main()
EOF
```

**Step 2: Create a sample document to summarize**

```bash
cat > sample-document.txt << 'EOF'
BC Government Digital Services Policy Framework - Version 2.1
December 2025

EXECUTIVE SUMMARY
The Province of British Columbia is committed to delivering modern, secure, and 
citizen-centric digital services. This policy establishes guidelines for all 
ministries deploying cloud-based solutions within the BC Government Azure Landing Zone.

KEY PRINCIPLES:
1. Security First - Zero-trust networking required. Private endpoints mandatory for
   all PaaS services. Public endpoints prohibited for sensitive workloads.

2. Data Residency - All Protected B data must remain in Canadian data centers.
   Primary regions: Canada Central (Toronto) and Canada East (Quebec City).

3. Cost Optimization - Auto-shutdown policies required for non-production VMs.
   Reserved instances recommended for workloads exceeding 12 months.

4. Identity Management - Azure AD integration mandatory. Service accounts must use
   managed identities. API keys stored in Azure Key Vault with RBAC.

5. Monitoring - All resources must send diagnostic logs to central Log Analytics.
   Azure Policy enforces compliance with guardrails automatically.

AI AND MACHINE LEARNING WORKLOADS:
- Azure AI Foundry for ML model development
- Private endpoints required for Cognitive Services
- Model inference must occur within landing zone boundary

COMPLIANCE TIMELINE:
- Q1 2025: All new deployments must comply
- Q4 2025: Full compliance required for existing workloads

Contact: Cloud Center of Excellence - cloud.coe@gov.bc.ca
EOF
```

**Step 3: Install dependencies and set environment variables**

**Option A: Automated Setup (Recommended)**

Run the setup script to install everything and create helper scripts:
```bash
# Download and run the setup script
curl -sL https://raw.githubusercontent.com/bcgov/AzureFilesPoC/feature/inventory-improvements/examples/setup-vm-env.sh | bash
```

This creates:
- `~/venv/` - Python virtual environment with OpenAI SDK
- `~/examples/activate-ai-env.sh` - Quick activation script
- `~/examples/summarize-document.py` - Document summarization script
- `~/load-ai-env.sh` - Environment loader (stays in current dir)

For subsequent sessions, just run:
```bash
source ~/examples/activate-ai-env.sh
```

**Option B: Manual Setup**

```bash
# Install venv package and create virtual environment (required on Ubuntu 24.04+)
sudo apt install -y python3.12-venv
python3 -m venv ~/venv
source ~/venv/bin/activate

# Install Python OpenAI SDK
pip install openai

# Set environment variables
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"

# Get API key (requires az login first)
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
  --name openai-ag-pssg-azure-files \
  --resource-group rg-ag-pssg-azure-files-azure-foundry \
  --query key1 -o tsv)

# Verify key was retrieved
echo "API Key set: ${AZURE_OPENAI_KEY:0:10}..."
```

> **Note:** Ubuntu 24.04+ uses externally-managed Python environments. Using a virtual environment
> (`venv`) is required. Remember to run `source ~/venv/bin/activate` in new SSH sessions.

**Step 4: Run the summarization**

```bash
python summarize-document.py sample-document.txt
```

**Expected output:**
```
Summarizing: sample-document.txt (1247 characters)
--------------------------------------------------

📄 SUMMARY:

This BC Government policy framework establishes cloud deployment guidelines:

**Key Points:**
• Zero-trust security with mandatory private endpoints (no public access)
• Data must stay in Canadian regions (Canada Central/East)
• Cost controls: VM auto-shutdown, reserved instances for long-term workloads
• Azure AD required; managed identities for service accounts
• Central logging via Log Analytics with policy enforcement

**AI/ML Requirements:**
• Use Azure AI Foundry with private endpoints
• All inference within landing zone boundary

**Timeline:** New deployments comply Q1 2025; full compliance by Q4 2025.

--------------------------------------------------
✅ Generated via private endpoint
```

---

### Option 2: Upload Files via Azure Blob Storage

For larger files or automated workflows, upload to blob storage from your local machine and access from VM via private endpoint.

#### Prerequisites
- Storage account `stagpssgazurepocdev01` has firewall rules allowing BC Gov IPs (`142.28-32.0.0/16`)
- VM accesses storage via private endpoint
- You are logged into Azure CLI (`az login`)
- `azcopy` installed on local machine

#### Step 1: Create a temporary blob container (one-time setup)

```powershell
# From local machine (PowerShell)
az storage container create --account-name stagpssgazurepocdev01 --name temp-ai-test --auth-mode login
```

#### Step 2: Upload files using the upload script

Use the provided `scripts/upload-to-blob.ps1` script:

```powershell
# Upload default sample file
.\scripts\upload-to-blob.ps1

# Or upload a specific file
.\scripts\upload-to-blob.ps1 -FilePath ".\path\to\myfile.txt"
```

The script:
- Generates a short-lived (1 hour) SAS token using storage account key
- Uploads the file with azcopy
- Shows the download command to run on VM

#### Step 3: Download on VM via private endpoint

```bash
# From VM (SSH session) - download using storage key auth
az storage blob download \
  --account-name stagpssgazurepocdev01 \
  --container-name temp-ai-test \
  --name sample-document.txt \
  --file ~/examples/sample-from-blob.txt \
  --auth-mode key

# List blobs in container
az storage blob list --account-name stagpssgazurepocdev01 --container-name temp-ai-test --auth-mode key -o table

# Verify download
ls -la ~/examples/
cat ~/examples/sample-from-blob.txt
```

> **Note:** We use `--auth-mode key` because Storage Blob Data Reader role is not assigned. 
> The VM can still access via private endpoint - the key is fetched via management plane.

#### Step 4: Set up environment and process the file

```bash
# Activate Python virtual environment
source ~/venv/bin/activate

# Set environment variables (if not already set)
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
  --name openai-ag-pssg-azure-files \
  --resource-group rg-ag-pssg-azure-files-azure-foundry \
  --query key1 -o tsv)

# Process the downloaded file
cd ~/examples
python summarize-document.py sample-from-blob.txt
```

#### Step 5: Cleanup (delete temp container when done)

```powershell
# From local machine (PowerShell)
az storage container delete --account-name stagpssgazurepocdev01 --name temp-ai-test --auth-mode login
```

---

### Helper Scripts Reference

| Script | Location | Purpose |
|--------|----------|---------|
| `upload-to-blob.ps1` | `scripts/` | Upload files from local machine to blob storage |
| `generate-sas.sh` | `~/` on VM | Generate SAS tokens (optional, for user delegation) |
| `summarize-document.py` | `~/examples/` on VM | Summarize documents using Azure OpenAI |

---

### Comparison: Direct Paste vs Blob Storage

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Direct Paste (Option 1)** | Quick tests, small files | Fast, no setup | Manual, not scalable |
| **Blob Storage (Option 2)** | Large files, automation | Scalable, auditable | More setup steps |

For PoC testing, start with Option 1. Use Option 2 for production workflows.

---

## Troubleshooting

### Common Issues

#### 1. AI Studio Playground Shows 403 Error
**Error:** "403: Public access is disabled. Please configure private endpoint."

**This is expected behavior.** The Azure OpenAI resource has public network access disabled. You must test from the VM via private endpoint, not from the AI Studio playground.

#### 2. Managed Identity Login Fails
**Error:** "No managed identity found" or "IMDS endpoint not available"

**Solution:** The VM's system-assigned managed identity may not have RBAC roles configured for the Azure OpenAI resource. Use device code login instead:
```bash
az login
# Follow the browser authentication flow
```

#### 3. API Returns "Unsupported parameter: max_tokens"
**Error:** `"Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead."`

**Solution:** gpt-5-nano and other reasoning models use `max_completion_tokens` instead of `max_tokens`:
```bash
# Wrong
-d '{"messages": [...], "max_tokens": 100}'

# Correct
-d '{"messages": [...], "max_completion_tokens": 500}'
```

#### 4. Model Response Content is Empty
**Error:** Response has `"content": ""` with all tokens used for `reasoning_tokens`

**Solution:** Reasoning models need more tokens for internal reasoning. Increase `max_completion_tokens`:
```bash
# Too low (100 tokens all used for reasoning)
"max_completion_tokens": 100

# Better (allows tokens for actual response)
"max_completion_tokens": 500
```

#### 5. DNS Does Not Resolve to Private IP
**Error:** nslookup returns public IP instead of 10.x.x.x

**Solutions:**
- Verify you're running from inside the VM (not your local machine)
- Check private endpoint status: `az network private-endpoint show --name pe-openai-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry`
- Wait 10-15 minutes for DNS propagation

> For infrastructure and Bastion troubleshooting, see the [Deployment Guide](./deployment-guide.md#troubleshooting) and [Bastion Connection Guide](../runbooks/bastion-connection.md#troubleshooting)