#!/bin/bash

# Azure Terraform Local Validation Script
# This script runs Terraform locally using credentials from your azure-credentials.json file
# to validate that you can create resources in Azure the same way GitHub Actions would.

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
VALIDATION_DIR="$PROJECT_ROOT/terraform/validation"

# Check if running from the wrong directory
if [[ ! -d "$VALIDATION_DIR" ]]; then
    echo -e "${RED}Error: Terraform validation directory not found at $VALIDATION_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}=== Terraform Validation ===${NC}"
echo -e "Validating Terraform deployment using credentials from: ${CREDS_FILE}"

# Check if credentials file exists
if [[ ! -f "$CREDS_FILE" ]]; then
    echo -e "${RED}Error: Credentials file not found at $CREDS_FILE${NC}"
    echo "Please make sure you've completed the RegisterApplicationInAzureAndOIDC process."
    exit 1
fi

# Extract values from JSON
CLIENT_ID=$(jq -r '.azure.ad.application.clientId // empty' "$CREDS_FILE")
TENANT_ID=$(jq -r '.azure.tenantId // empty' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id // empty' "$CREDS_FILE")

# Validate that we have all required values
if [[ -z "$CLIENT_ID" || -z "$TENANT_ID" || -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}Error: Missing required credentials in $CREDS_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}Found credentials:${NC}"
echo "- Client ID: ${CLIENT_ID:0:8}..."
echo "- Tenant ID: ${TENANT_ID:0:8}..."
echo "- Subscription ID: ${SUBSCRIPTION_ID:0:8}..."

# Ensure we're authenticated with Azure CLI
echo -e "${BLUE}Checking Azure authentication status...${NC}"
CURRENT_ACCOUNT=$(az account show --query id -o tsv 2>/dev/null || echo "")

if [[ -z "$CURRENT_ACCOUNT" ]]; then
    echo "Not authenticated with Azure CLI. Please run ./validate_authentication.sh first."
    exit 1
fi

if [[ "$CURRENT_ACCOUNT" != "$SUBSCRIPTION_ID" ]]; then
    echo "Switching to correct subscription..."
    az account set --subscription "$SUBSCRIPTION_ID"
fi

echo -e "${BLUE}Setting environment variables for Terraform...${NC}"
# Set environment variables that Terraform Azure provider will use
export ARM_CLIENT_ID="$CLIENT_ID"
export ARM_TENANT_ID="$TENANT_ID"
export ARM_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export ARM_USE_CLI=true

# Navigate to the validation directory
cd "$VALIDATION_DIR"

echo -e "${BLUE}Running Terraform init...${NC}"
terraform init

echo -e "${BLUE}Running Terraform plan...${NC}"
terraform plan -out=tfplan

echo -e "${BLUE}Running Terraform apply...${NC}"
terraform apply -auto-approve tfplan

echo -e "${GREEN}Terraform validation successful!${NC}"
echo -e "${BLUE}Resource outputs:${NC}"
terraform output

echo -e "${BLUE}Cleaning up resources...${NC}"
read -p "Do you want to clean up the created resources? (y/n): " CLEANUP

if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then
    echo "Running terraform destroy..."
    terraform destroy -auto-approve
    echo -e "${GREEN}Resources successfully removed.${NC}"
else
    echo "Resources will be preserved. You can manually clean up later with:"
    echo "cd $VALIDATION_DIR && terraform destroy"
fi

echo -e "${GREEN}Validation process complete!${NC}"
echo "Your Azure OIDC setup is correctly configured and working with Terraform."
