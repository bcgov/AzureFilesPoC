#!/bin/bash

# Function to check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Function to verify prerequisites
verify_prerequisites() {
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is required but not installed."
        if is_macos; then
            echo "Install using: brew update && brew install azure-cli"
        else
            echo "Install using your package manager or visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        fi
        exit 1
    fi

    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed."
        if is_macos; then
            echo "Install using: brew install jq"
        else
            echo "Install using your package manager"
        fi
        exit 1
    fi
}

# Function to resolve script location and set correct paths
resolve_script_path() {
    local script_path
    # Get the real path of the script, resolving any symlinks
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Extract the directory
    SCRIPT_DIR="$(dirname "$script_path")"
    
    # Navigate to project root (up from scripts/unix/RegisterApplicationInAzureAndOIDC/OneTimeActivities)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
    
    echo "Script running from: $SCRIPT_DIR"
    echo "Project root: $PROJECT_ROOT"
}

# Call path resolution function
resolve_script_path

# Verify prerequisites
verify_prerequisites

# Check if credentials file exists
CREDS_FILE="$PROJECT_ROOT/.env/azure-credentials.json"

if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please run step1_register_app.sh first"
    exit 1
fi

# Read credentials using correct JSON paths
CLIENT_ID=$(jq -r '.azure.ad.application.clientId' "$CREDS_FILE")
TENANT_ID=$(jq -r '.azure.ad.tenantId' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id' "$CREDS_FILE")
GITHUB_ORG=$(jq -r '.github.org' "$CREDS_FILE")
GITHUB_REPO=$(jq -r '.github.repo' "$CREDS_FILE")

echo "========== GitHub Secrets Setup Guide =========="
echo "These values need to be added as GitHub repository secrets."
echo ""
echo "1. Open your browser and navigate to:"
echo "   https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "2. Click on 'New repository secret' and add each of these secrets:"
echo ""
echo "AZURE_CLIENT_ID:"
echo "$CLIENT_ID"
echo ""
echo "AZURE_TENANT_ID:"
echo "$TENANT_ID"
echo ""
echo "AZURE_SUBSCRIPTION_ID:"
echo "$SUBSCRIPTION_ID"
echo ""

# Update secrets configuration in JSON file
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
TEMP_FILE=$(mktemp)

jq --arg clientId "$CLIENT_ID" \
   --arg tenantId "$TENANT_ID" \
   --arg subId "$SUBSCRIPTION_ID" \
   --arg timestamp "$TIMESTAMP" '
.github.secrets = {
  "configured": ["AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"],
  "configuredOn": $timestamp,
  "available": ["AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"]
} |
.github.clientId = $clientId |
.github.tenantId = $tenantId |
.github.subscriptionId = $subId
' "$CREDS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CREDS_FILE"

echo "3. Secrets configuration has been recorded in $CREDS_FILE"
echo "4. Update the Progress Tracking table in README.md to mark this step as complete"
echo ""
echo "For security, these values are never stored in the repository."
echo "Remember to keep them secure and never share them."
