#!/bin/bash

# Azure Terraform Local Validation Script
#
# This script runs Terraform commands (init, plan, apply, destroy) in the
# terraform/validation directory. It does NOT reference a specific .tf file;
# instead, Terraform automatically loads all cd "$VALIDATION_DIR".tf files in the current directory.
# In this case, it uses main.tf (and any other .tf files) in terraform/validation.
#
# This script is intended to:
#   - Validate that your Azure credentials and permissions are correct
#   - Test that you can create and destroy resources in Azure using Terraform
#   - Mirror the same Terraform code and process used by GitHub Actions workflows
#
# Prerequisites:
#   - Complete onboarding and OIDC setup (see project documentation)
#   - Authenticate with Azure CLI (az login)
#   - Ensure .env/azure-credentials.json is populated
#   - Run from the project root or any subdirectory
#
# For more details, see validation/localhost/README.md
#
# NOTE: If you see an error like:
#   Error: building account: could not acquire access token to parse claims: running Azure CLI: exit status 1: ERROR: AADSTS70043: The refresh token has expired or is invalid...
#
# This means your Azure CLI session has expired or is invalid. To fix:
#   1. Run this command in your terminal:
#        az login --scope https://graph.microsoft.com/.default
#      (This will open a browser window for you to log in and refresh your credentials.)
#   2. If you have multiple subscriptions, set the correct one:
#        az account set --subscription "<your-subscription-id>"
#   3. Re-run this Terraform validation script.
#

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

# Extract values from JSON (use only the nested Azure keys)
CLIENT_ID=$(jq -r '.azure.ad.application.clientId // empty' "$CREDS_FILE")
TENANT_ID=$(jq -r '.azure.ad.tenantId // empty' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id // empty' "$CREDS_FILE")

# Validate that we have all required values
if [[ -z "$CLIENT_ID" || -z "$TENANT_ID" || -z "$SUBSCRIPTION_ID" ]]; then
    echo -e "${RED}Error: Missing required credentials in $CREDS_FILE${NC}"
    echo "Please ensure your credentials file has the correct Azure keys."
    exit 1
fi

echo -e "${BLUE}Found credentials:${NC}"
echo "- Client ID: ${CLIENT_ID:0:8}..."
echo "- Tenant ID: ${TENANT_ID:0:8}..."
echo "- Subscription ID: ${SUBSCRIPTION_ID:0:8}..."

# Ensure we're authenticated with Azure CLI
# (OIDC: user must run 'az login' interactively; no secret required)
echo -e "${BLUE}Checking Azure authentication status...${NC}"
CURRENT_ACCOUNT=$(az account show --query id -o tsv 2>/dev/null || echo "")

if [[ -z "$CURRENT_ACCOUNT" ]]; then
    echo -e "${RED}Not authenticated with Azure CLI.${NC}"
    echo "Please run 'az login --scope https://graph.microsoft.com/.default' in your terminal and authenticate as your user, then re-run this script."
    exit 1
fi

# Check if the token is expired (simulate by running a simple az command)
az account get-access-token --resource https://management.azure.com/ > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Your Azure CLI session has expired or is invalid.${NC}"
    echo "Please run 'az login --scope https://graph.microsoft.com/.default' to re-authenticate, then re-run this script."
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
# prepare directory for use with terraform
# Initializes a Terraform working directory by performing several steps:
# 1. Loads backend configuration to determine where state is stored.
# 2. Downloads and installs the required provider plugins.
# 3. Prepares the working directory for use with Terraform, including creating necessary local files.
# 4. Validates the configuration files for syntax errors.
# 5. Optionally configures remote backends and checks for required provider versions.
# 6. Ensures that all modules referenced in the configuration are downloaded.
terraform init

echo -e "${BLUE}Running Terraform plan...${NC}"
# Executes a speculative plan to preview changes that Terraform will make to the infrastructure.
# This command shows which resources will be created, updated, or destroyed, without applying any changes.
# Useful for reviewing and validating infrastructure modifications before actual deployment.
terraform plan -out=tfplan -var-file=../terraform.tfvars

echo -e "${BLUE}Running Terraform apply...${NC}"
terraform apply tfplan

echo -e "${GREEN}Terraform validation successful!${NC}"
echo -e "${BLUE}Resource outputs:${NC}"
# Show all Terraform outputs in JSON format for easier inspection
terraform output -json | jq .
terraform output

echo -e "${BLUE}Cleaning up resources...${NC}"
read -p "Do you want to clean up the created resources? (y/n): " CLEANUP

if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then
    echo "Running terraform destroy..."
    # Destroys all resources created by Terraform in the current directory.
    # This command will remove all infrastructure managed by Terraform, reverting the state to empty.
    # The -auto-approve flag is intentionally omitted to require manual approval for safety.
    terraform destroy -var-file=../terraform.tfvars
    echo -e "${GREEN}Resources successfully removed.${NC}"
else
    echo "Resources will be preserved. You can manually clean up later with:"
    echo "cd $VALIDATION_DIR && terraform destroy -var-file=../terraform.tfvars"
fi

echo -e "${GREEN}Validation process complete!${NC}"
echo "Your Azure OIDC setup is correctly configured and working with Terraform."
