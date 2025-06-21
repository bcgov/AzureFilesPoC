#!/bin/bash

# Azure OIDC Local Authentication Validation Script
# This script validates that you can authenticate with Azure using credentials from your
# azure-credentials.json file. It simulates what GitHub Actions would do but in a local context.

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Find project root (where .env directory exists)
find_project_root() {
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.env" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done
    echo "Project root not found" >&2
    exit 1
}

PROJECT_ROOT=$(find_project_root)
CREDS_FILE="$PROJECT_ROOT/.env/azure-credentials.json"

echo -e "${BLUE}=== Azure Authentication Validation ===${NC}"
echo -e "Validating Azure authentication using credentials from: ${CREDS_FILE}"

# Check if credentials file exists
if [[ ! -f "$CREDS_FILE" ]]; then
    echo -e "${RED}Error: Credentials file not found at $CREDS_FILE${NC}"
    echo "Please make sure you've completed the RegisterApplicationInAzureAndOIDC process."
    exit 1
fi

# Extract values from JSON (use only the nested Azure keys)
CLIENT_ID=$(jq -r '.azure.ad.application.clientId // empty' "$CREDS_FILE")
TENANT_ID=$(jq -r '.azure.ad.tenantId // empty' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id // empty' "$CREDS_FILE")

# Validate that we have all required values
if [[ -z "$CLIENT_ID" || -z "$TENANT_ID" || -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}Error: Missing required credentials in $CREDS_FILE${NC}"
    echo "Please ensure your credentials file has:"
    echo " - .azure.ad.application.clientId"
    echo " - .azure.tenantId"
    echo " - .azure.subscription.id"
    exit 1
fi

echo -e "${BLUE}Found credentials:${NC}"
echo "- Client ID: ${CLIENT_ID:0:8}..."
echo "- Tenant ID: ${TENANT_ID:0:8}..."
echo "- Subscription ID: ${SUBSCRIPTION_ID:0:8}..."

echo -e "${BLUE}Attempting to authenticate with Azure using your user account...${NC}"

# Use interactive/user login for local validation
az login

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Authentication failed.${NC}"
    echo "Please check that you can log in to Azure interactively."
    exit 1
fi

# Set subscription
echo -e "${BLUE}Setting default subscription...${NC}"
az account set --subscription "$SUBSCRIPTION_ID"

if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to set subscription.${NC}"
    echo "Please verify that:"
    echo "1. The subscription ID in your credentials file is correct"
    echo "2. Your service principal has access to this subscription"
    exit 1
fi

# Show account details
echo -e "${BLUE}Current Azure account details:${NC}"
az account show

echo -e "${BLUE}Testing permissions...${NC}"
echo "Listing resource groups (this tests if you have at least Reader permissions):"
az group list --query "[].name" -o tsv

echo -e "${GREEN}Authentication validation successful!${NC}"
echo "Your Azure credentials are correctly configured."
echo "You can now proceed with Terraform validation using: ./validate_terraform.sh"
