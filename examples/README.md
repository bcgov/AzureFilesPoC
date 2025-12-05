# Azure AI Foundry Examples

Sample scripts and documents for testing Azure OpenAI via private endpoints.

## Contents

| File | Description |
|------|-------------|
| `sample-document.txt` | Sample BC Gov policy document for summarization |
| `summarize-document.py` | Python script to summarize documents using Azure OpenAI |
| `analyze-sentiment.py` | Python script for sentiment analysis |

## Prerequisites

1. SSH into the VM via Bastion (see [Bastion Connection Guide](../docs/runbooks/bastion-connection.md))
2. Set environment variables (see below)
3. Install Python dependencies: `pip install openai`

## Environment Variables

Set these before running the scripts:

```bash
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_KEY="<your-key>"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"
```

## Quick Start

```bash
# From the VM, clone or copy these files, then:
cd examples
python summarize-document.py sample-document.txt
```

## Testing Private Endpoint Connectivity

The scripts connect to Azure OpenAI via private endpoint. If connectivity fails:
- Verify DNS resolves to private IP: `nslookup openai-ag-pssg-azure-files.openai.azure.com`
- Check NSG rules allow outbound to the PE subnet
