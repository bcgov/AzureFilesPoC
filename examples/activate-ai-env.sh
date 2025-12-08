#!/bin/bash
# Filename: examples/activate-ai-env.sh
# Activate Python environment and set Azure OpenAI variables
# Usage: source ~/examples/activate-ai-env.sh

# Activate Python virtual environment
source ~/venv/bin/activate

# Change to examples directory
cd ~/examples

# Set Azure OpenAI environment variables
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"

# Get API key from Azure (requires az login)
echo "Fetching API key from Azure..."
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
  --name openai-ag-pssg-azure-files \
  --resource-group rg-ag-pssg-azure-files-azure-foundry \
  --query key1 -o tsv)

if [ -z "$AZURE_OPENAI_KEY" ]; then
    echo "WARNING: Failed to get API key. Run 'az login' first."
else
    echo "API Key: ${AZURE_OPENAI_KEY:0:10}..."
    echo ""
    echo "Environment ready! Run:"
    echo "  python summarize-document.py sample-document.txt"
fi
