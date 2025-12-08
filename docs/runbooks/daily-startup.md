# Daily Startup Runbook

Quick reference for starting Azure resources, connecting to the VM, and testing the AI model.

## Quick Start (TL;DR)

```powershell
# 1. Start VM and Bastion (~5 min)
.\scripts\start-azure-resources.ps1

# 2. Connect via Bastion
az network bastion ssh --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry --target-resource-id "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-01" --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa_azure
```

```bash
# 3. On VM: Quick AI test
source ~/examples/activate-ai-env.sh
python summarize-document.py sample-document.txt
```

---

## Step 1: Start Azure Resources

From your local machine (PowerShell), run the start script:

```powershell
.\scripts\start-azure-resources.ps1
```

**What it does:**
- Starts the deallocated VM (`vm-ag-pssg-azure-files-01`)
- Deploys Azure Bastion using Bicep templates
- Creates the Bastion public IP (required for Bastion)

**Expected output:**
```
==========================================
Starting Azure Resources
==========================================
Resource Group: rg-ag-pssg-azure-files-azure-foundry
VM Name: vm-ag-pssg-azure-files-01
Bastion: bastion-ag-pssg-azure-files

Checking current resource status...
   VM Status: VM deallocated
   Bastion: Not deployed

==========================================
[1/2] Starting VM
==========================================
Starting VM...
VM started successfully!

==========================================
[2/2] Deploying Bastion
==========================================
...
==========================================
Resources Ready!
==========================================
```

**Duration:** ~5 minutes (VM starts quickly, Bastion takes 3-4 minutes)

---

## Step 2: Connect to VM via Bastion

Once resources are ready, connect via SSH through Bastion:

```powershell
az network bastion ssh `
  --name bastion-ag-pssg-azure-files `
  --resource-group rg-ag-pssg-azure-files-azure-foundry `
  --target-resource-id "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-01" `
  --auth-type ssh-key `
  --username azureuser `
  --ssh-key ~/.ssh/id_rsa_azure
```

**One-liner version:**
```powershell
az network bastion ssh --name bastion-ag-pssg-azure-files --resource-group rg-ag-pssg-azure-files-azure-foundry --target-resource-id "/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/resourceGroups/rg-ag-pssg-azure-files-azure-foundry/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-01" --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa_azure
```

**Troubleshooting:**
- If connection fails, wait 1-2 minutes for Bastion to fully provision
- Verify SSH key exists: `Test-Path ~/.ssh/id_rsa_azure`
- See [Bastion Connection Guide](./bastion-connection.md) for more details

---

## Step 3: Set Up VM Environment (First Time Only)

If this is a fresh VM or after VM recreation, run the setup script:

```bash
# Download and run setup script
curl -sL https://raw.githubusercontent.com/bcgov/AzureFilesPoC/feature/inventory-improvements/examples/setup-vm-env.sh | bash
```

Or manually:
```bash
# Install Python venv package
sudo apt update && sudo apt install -y python3.12-venv

# Create virtual environment
python3 -m venv ~/venv
source ~/venv/bin/activate

# Install required packages
pip install openai azure-identity

# Create examples directory
mkdir -p ~/examples

# Login to Azure
az login
```

---

## Step 4: Test AI Model with Python Script

### Option A: Quick Test (Recommended)

```bash
# Activate environment and set variables (one command)
source ~/examples/activate-ai-env.sh

# Run summarization test
python summarize-document.py sample-document.txt
```

### Option B: Manual Setup (if script doesn't exist)

```bash
# Activate environment
source ~/venv/bin/activate
cd ~/examples

# Set environment variables
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
  --name openai-ag-pssg-azure-files \
  --resource-group rg-ag-pssg-azure-files-azure-foundry \
  --query key1 -o tsv)

# Verify key was retrieved
echo "API Key: ${AZURE_OPENAI_KEY:0:10}..."

# Run summarization test
python summarize-document.py sample-document.txt
```

### Option B: Create Script Files on VM

If the scripts don't exist on VM yet, create them:

**Create summarize-document.py:**
```bash
cat > ~/examples/summarize-document.py << 'SCRIPT'
#!/usr/bin/env python3
"""Summarize a document using Azure OpenAI via private endpoint."""
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
    
    print(f"Summarizing: {filepath} ({len(text)} chars)")
    print("-" * 50)
    
    client = AzureOpenAI(azure_endpoint=endpoint, api_key=api_key, api_version="2024-12-01-preview")
    
    response = client.chat.completions.create(
        model=deployment,
        messages=[
            {"role": "system", "content": "Summarize documents concisely with key points."},
            {"role": "user", "content": f"Summarize:\n\n{text}"}
        ],
        max_completion_tokens=1000,
        reasoning_effort="low"
    )
    
    print("\nSUMMARY:\n")
    print(response.choices[0].message.content)
    print("\n" + "-" * 50)
    print("Generated via private endpoint")

if __name__ == "__main__":
    main()
SCRIPT
```

**Create sample-document.txt:**
```bash
cat > ~/examples/sample-document.txt << 'DOC'
BC Government Digital Services Policy Framework - Version 2.1

EXECUTIVE SUMMARY
The Province of British Columbia is committed to delivering modern, secure, and 
citizen-centric digital services. This policy establishes guidelines for all 
ministries deploying cloud-based solutions within the BC Government Azure Landing Zone.

KEY PRINCIPLES:
1. Security First - Zero-trust networking required. Private endpoints mandatory.
2. Data Residency - All Protected B data must remain in Canadian data centers.
3. Cost Optimization - Auto-shutdown policies required for non-production VMs.
4. Identity Management - Azure AD integration mandatory. Use managed identities.
5. Monitoring - All resources must send logs to central Log Analytics.

AI AND MACHINE LEARNING WORKLOADS:
- Azure AI Foundry for ML model development
- Private endpoints required for Cognitive Services
- Model inference must occur within landing zone boundary

COMPLIANCE TIMELINE:
- Q1 2025: All new deployments must comply
- Q4 2025: Full compliance required for existing workloads
DOC
```

### Expected Output

```
Summarizing: sample-document.txt (892 chars)
--------------------------------------------------

SUMMARY:

**Main Purpose:** BC Government policy framework establishing guidelines for 
cloud deployments within the Azure Landing Zone, focusing on security and compliance.

**Key Points:**
• Zero-trust security with mandatory private endpoints (no public access)
• Data residency in Canadian regions (Canada Central/East)
• Cost controls including VM auto-shutdown policies
• Azure AD integration with managed identities required
• Central logging via Log Analytics

**Timeline:**
• Q1 2025: New deployments must comply
• Q4 2025: Full compliance for existing workloads

--------------------------------------------------
Generated via private endpoint
```

---

## Step 5: End of Day - Stop Resources

When done for the day, stop resources to save costs:

```powershell
.\scripts\stop-azure-resources.ps1
```

**What it does:**
- Deallocates the VM (keeps disk, stops billing for compute)
- Deletes Bastion and its public IP (Bastion costs ~$140/month)

**Cost savings:**
| Resource | Running Cost | Stopped Cost |
|----------|--------------|--------------|
| VM (B2s) | ~$30/month | ~$5/month (disk only) |
| Bastion | ~$140/month | $0 (deleted) |

---

## Troubleshooting

### VM won't start
```powershell
# Check VM status
az vm get-instance-view --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry --query "instanceView.statuses[1].displayStatus" -o tsv

# Manual start
az vm start --name vm-ag-pssg-azure-files-01 --resource-group rg-ag-pssg-azure-files-azure-foundry
```

### Bastion connection times out
- Wait 2-3 minutes after deploy script completes
- Check Bastion status in Azure Portal
- Verify your IP is allowed (BC Gov VPN required)

### AI model returns empty content
The `gpt-5-nano` model is a **reasoning model**. It uses tokens for internal reasoning before generating output. Our script includes `reasoning_effort="low"` to ensure visible output.

If you still get empty content:
```python
# Increase token limit
max_completion_tokens=1000  # Not max_tokens!
reasoning_effort="low"      # Required for reasoning models
```

### Python venv not found
```bash
# Recreate virtual environment
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install openai azure-identity
```

### Azure CLI not logged in
```bash
# Use device code login
az login
# Follow the browser instructions
```

---

## Related Runbooks

- [Daily Shutdown Runbook](./daily-shutdown.md) - Stop VM and delete Bastion (end of day)
- [Bastion Connection Guide](./bastion-connection.md) - Detailed connection troubleshooting
- [VM Shutdown](./vm-shutdown.md) - Manual VM management
- [VM Updates](./vm-updates.md) - Applying OS updates
- [AI Model Testing Guide](../guides/ai-model-testing.md) - Full AI testing documentation

---

## Scripts Reference

| Script | Location | Purpose |
|--------|----------|---------|
| `start-azure-resources.ps1` | `scripts/` | Start VM + deploy Bastion |
| `stop-azure-resources.ps1` | `scripts/` | Stop VM + delete Bastion |
| `activate-ai-env.sh` | `examples/` | Activate venv + set Azure OpenAI env vars |
| `summarize-document.py` | `examples/` | Summarize docs with Azure OpenAI |
| `setup-vm-env.sh` | `examples/` | One-command VM setup |
| `upload-to-blob.ps1` | `examples/` | Upload files to blob storage |
| `process-blob-file.sh` | `examples/` | Full blob download + summarize pipeline |
