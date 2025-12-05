#!/bin/bash
# Process and summarize a file from Azure Blob Storage
# Usage: ./process-blob-file.sh [blob-name]
# This script downloads a file from blob storage and summarizes it using Azure OpenAI

set -e

BLOB_NAME="${1:-sample-document.txt}"
LOCAL_FILE="$HOME/examples/$(basename $BLOB_NAME)"
STORAGE_ACCOUNT="stagpssgazurepocdev01"
CONTAINER_NAME="temp-ai-test"

echo "🔄 Azure AI Document Processing Pipeline"
echo "=========================================="
echo ""

# Step 1: Activate virtual environment
echo "1️⃣  Activating Python virtual environment..."
source ~/venv/bin/activate

# Step 2: Set environment variables
echo "2️⃣  Loading Azure OpenAI credentials..."
export AZURE_OPENAI_ENDPOINT="https://openai-ag-pssg-azure-files.openai.azure.com"
export AZURE_OPENAI_DEPLOYMENT="gpt-5-nano"
export AZURE_OPENAI_KEY=$(az cognitiveservices account keys list \
    --name openai-ag-pssg-azure-files \
    --resource-group rg-ag-pssg-azure-files-azure-foundry \
    --query key1 -o tsv 2>/dev/null)

if [ -z "$AZURE_OPENAI_KEY" ]; then
    echo "❌ Failed to retrieve Azure OpenAI key"
    echo "   Make sure you're logged in with: az login"
    exit 1
fi
echo "   ✅ Credentials loaded"

# Step 3: Download from blob storage
echo "3️⃣  Downloading from blob storage via private endpoint..."
az storage blob download \
    --account-name $STORAGE_ACCOUNT \
    --container-name $CONTAINER_NAME \
    --name "$BLOB_NAME" \
    --file "$LOCAL_FILE" \
    --auth-mode key \
    --only-show-errors

if [ ! -f "$LOCAL_FILE" ]; then
    echo "❌ Download failed: $LOCAL_FILE not found"
    exit 1
fi
echo "   ✅ Downloaded: $LOCAL_FILE"

# Step 4: Show file preview
echo ""
echo "📄 File Preview (first 5 lines):"
echo "---"
head -5 "$LOCAL_FILE"
echo "---"
echo ""

# Step 5: Summarize with Azure OpenAI
echo "4️⃣  Sending to Azure OpenAI for summarization..."
echo ""
echo "📝 Summary:"
echo "==========="
python ~/examples/summarize-document.py "$LOCAL_FILE"

echo ""
echo "==========================================="
echo "✅ Processing complete!"
echo ""
echo "Files:"
echo "  - Source: blob://$STORAGE_ACCOUNT/$CONTAINER_NAME/$BLOB_NAME"
echo "  - Local: $LOCAL_FILE"
