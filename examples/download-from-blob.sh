#!/bin/bash
# Download file from Azure Blob Storage via private endpoint
# Usage: ./download-from-blob.sh [filename] [local-path]

STORAGE_ACCOUNT="stagpssgazurepocdev01"
CONTAINER_NAME="temp-ai-test"

BLOB_NAME="${1:-sample-document.txt}"
LOCAL_PATH="${2:-$HOME/examples/$BLOB_NAME}"

echo "📥 Downloading from blob storage..."
echo "   Storage: $STORAGE_ACCOUNT"
echo "   Container: $CONTAINER_NAME"
echo "   Blob: $BLOB_NAME"
echo "   Destination: $LOCAL_PATH"
echo ""

# List available blobs
echo "📋 Available blobs in container:"
az storage blob list \
    --account-name $STORAGE_ACCOUNT \
    --container-name $CONTAINER_NAME \
    --auth-mode key \
    --query "[].{Name:name, Size:properties.contentLength, Modified:properties.lastModified}" \
    -o table

echo ""

# Download the file
az storage blob download \
    --account-name $STORAGE_ACCOUNT \
    --container-name $CONTAINER_NAME \
    --name "$BLOB_NAME" \
    --file "$LOCAL_PATH" \
    --auth-mode key \
    --only-show-errors

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Download complete: $LOCAL_PATH"
    echo ""
    echo "File contents (first 10 lines):"
    echo "--------------------------------"
    head -10 "$LOCAL_PATH"
    echo ""
    echo "--------------------------------"
    echo ""
    echo "To summarize this file, run:"
    echo "  python ~/examples/summarize-document.py $LOCAL_PATH"
else
    echo "❌ Download failed"
    exit 1
fi
