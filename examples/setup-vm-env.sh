#!/bin/bash
# VM Environment Setup Script for Azure AI Testing
# Run this script after connecting to the VM via Bastion
#
# Usage: curl -sL <raw-url> | bash
#    or: ./setup-vm-env.sh

set -e

echo "🚀 Setting up VM environment for Azure AI testing..."
echo ""

# Configuration
OPENAI_RESOURCE="openai-ag-pssg-azure-files"
OPENAI_RG="rg-ag-pssg-azure-files-azure-foundry"
OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
OPENAI_DEPLOYMENT="gpt-5-nano"

# Step 1: Install Python venv if needed
echo "📦 Step 1: Checking Python virtual environment..."
if [ ! -d "$HOME/venv" ]; then
    echo "Installing python3.12-venv..."
    sudo apt update && sudo apt install -y python3.12-venv
    echo "Creating virtual environment..."
    python3 -m venv ~/venv
fi
source ~/venv/bin/activate
echo "✅ Virtual environment activated"

# Step 2: Install OpenAI SDK
echo ""
echo "📦 Step 2: Installing OpenAI SDK..."
pip install --quiet --upgrade openai
echo "✅ OpenAI SDK installed"

# Step 3: Create examples directory
echo ""
echo "📁 Step 3: Creating examples directory..."
mkdir -p ~/examples
cd ~/examples

# Step 4: Check Azure CLI login
echo ""
echo "🔐 Step 4: Checking Azure CLI login..."
if ! az account show > /dev/null 2>&1; then
    echo "Not logged in. Running az login..."
    az login
fi
ACCOUNT=$(az account show --query name -o tsv)
echo "✅ Logged in to: $ACCOUNT"

# Step 5: Get OpenAI API key
echo ""
echo "🔑 Step 5: Getting Azure OpenAI API key..."
export AZURE_OPENAI_ENDPOINT="$OPENAI_ENDPOINT"
export AZURE_OPENAI_DEPLOYMENT="$OPENAI_DEPLOYMENT"
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
    --name $OPENAI_RESOURCE \
    --resource-group $OPENAI_RG \
    --query key1 -o tsv)

if [ -z "$AZURE_OPENAI_KEY" ]; then
    echo "❌ Failed to get API key"
    exit 1
fi
echo "✅ API key retrieved: ${AZURE_OPENAI_KEY:0:10}..."

# Step 6: Test connectivity
echo ""
echo "🔍 Step 6: Testing private endpoint connectivity..."
PRIVATE_IP=$(nslookup $OPENAI_RESOURCE.openai.azure.com 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
if [[ $PRIVATE_IP == 10.* ]]; then
    echo "✅ Private endpoint working: $PRIVATE_IP"
else
    echo "⚠️ Warning: DNS may not be resolving to private IP"
fi

# Step 7: Create helper scripts
echo ""
echo "📝 Step 7: Creating helper scripts..."

# Create summarize script if it doesn't exist
if [ ! -f ~/examples/summarize-document.py ]; then
cat > ~/examples/summarize-document.py << 'PYEOF'
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
PYEOF
chmod +x ~/examples/summarize-document.py
echo "  Created: ~/examples/summarize-document.py"
fi

# Create env loader script (in home directory)
cat > ~/load-ai-env.sh << 'ENVEOF'
#!/bin/bash
# Load AI environment variables
# Usage: source ~/load-ai-env.sh

source ~/venv/bin/activate

export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
    --name openai-ag-pssg-azure-files \
    --resource-group rg-ag-pssg-azure-files-azure-foundry \
    --query key1 -o tsv 2>/dev/null)

if [ -n "$AZURE_OPENAI_KEY" ]; then
    echo "✅ AI environment loaded"
    echo "   Endpoint: $AZURE_OPENAI_ENDPOINT"
    echo "   Deployment: $AZURE_OPENAI_DEPLOYMENT"
    echo "   API Key: ${AZURE_OPENAI_KEY:0:10}..."
else
    echo "❌ Failed to load API key. Run 'az login' first."
fi
ENVEOF
chmod +x ~/load-ai-env.sh
echo "  Created: ~/load-ai-env.sh"

# Create activate script (in examples directory - changes to examples dir)
cat > ~/examples/activate-ai-env.sh << 'ACTEOF'
#!/bin/bash
# Activate Python environment and set Azure OpenAI variables
# Usage: source ~/examples/activate-ai-env.sh

source ~/venv/bin/activate
cd ~/examples

export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"

echo "Fetching API key from Azure..."
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
    --name openai-ag-pssg-azure-files \
    --resource-group rg-ag-pssg-azure-files-azure-foundry \
    --query key1 -o tsv 2>/dev/null)

if [ -z "$AZURE_OPENAI_KEY" ]; then
    echo "WARNING: Failed to get API key. Run 'az login' first."
else
    echo "API Key: ${AZURE_OPENAI_KEY:0:10}..."
    echo ""
    echo "Ready! Run: python summarize-document.py sample-document.txt"
fi
ACTEOF
chmod +x ~/examples/activate-ai-env.sh
echo "  Created: ~/examples/activate-ai-env.sh"

# Summary
echo ""
echo "=============================================="
echo "✅ VM environment setup complete!"
echo "=============================================="
echo ""
echo "Environment variables set:"
echo "  AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT"
echo "  AZURE_OPENAI_DEPLOYMENT=$AZURE_OPENAI_DEPLOYMENT"
echo "  AZURE_OPENAI_KEY=${AZURE_OPENAI_KEY:0:10}..."
echo ""
echo "Quick commands:"
echo "  source ~/examples/activate-ai-env.sh   # Activate env + cd to examples"
echo "  source ~/load-ai-env.sh                # Just activate env (stay in current dir)"
echo "  python ~/examples/summarize-document.py <file>"
echo ""
echo "To test:"
echo "  source ~/examples/activate-ai-env.sh"
echo "  python summarize-document.py sample-document.txt"
