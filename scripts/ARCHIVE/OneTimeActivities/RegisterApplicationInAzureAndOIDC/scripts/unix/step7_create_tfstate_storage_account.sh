#!/usr/bin/env bash
# step7_create_tfstate_storage_account.sh
# -----------------------------------------------------------------------------
# SUMMARY:
#   This script creates an Azure Storage Account and Blob Container specifically
#   for storing Terraform state files. These resources must exist before 'terraform init'
#   can be run successfully with a remote backend configuration.
#
# WHAT IT DOES:
#   - Creates a secure storage account with appropriate settings for Terraform state
#   - Creates a blob container within the storage account for state file storage
#   - Updates the local azure_full_inventory.json for tracking and reference
#   - Validates that the tfstate resource group exists before creation
#
# USAGE:
#   bash step7_create_tfstate_storage_account.sh \
#     --rgname "rg-<project-name>-tfstate-dev" \
#     --saname "st<projectname>tfstatedev01" \
#     --containername "sc-<project-name>-tfstate-dev" \
#     --location "<azure-region>"
#
# PREREQUISITES:
#   - Azure CLI installed and authenticated to the target subscription
#   - The Terraform state resource group must already exist (created by step6_create_resource_group.sh)
#   - Sufficient permissions to create Storage Accounts and Blob Containers
#   - jq installed for JSON processing
#
# IMPLEMENTATION NOTES:
#   - Idempotent: re-running will not create duplicate resources or cause errors
#   - Storage account uses Standard_LRS SKU for cost optimization
#   - StorageV2 kind with modern features enabled
#   - Public blob access disabled for security
#   - Minimum TLS version set to 1.2 for security compliance
#   - Updates inventory file atomically using temporary files
#
# NEXT STEPS:
#   1. Verify the storage account and container in the Azure Portal
#   2. Update terraform backend configuration with the created resources
#   3. Run 'terraform init' to initialize the remote backend
#   4. Mark this step as complete in the onboarding checklist
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Resolve script directory for robust inventory updates ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- ARGUMENT PARSING ---
RG_NAME=""
SA_NAME=""
CONTAINER_NAME=""
LOCATION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --rgname)
      RG_NAME="$2"; shift 2;;
    --saname)
      SA_NAME="$2"; shift 2;;
    --containername)
      CONTAINER_NAME="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --rgname <resource-group-name> --saname <storage-account-name> --containername <container-name> [--location <location>]"
      echo "Example: $0 --rgname rg-<project-name>-tfstate-dev --saname st<projectname>tfstatedev01 --containername sc-<project-name>-tfstate-dev --location <azure-region>"
      exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$RG_NAME" || -z "$SA_NAME" || -z "$CONTAINER_NAME" ]]; then
  echo "Error: Resource group name, storage account name, and container name are required."
  echo "Use --rgname <resource-group-name> --saname <storage-account-name> --containername <container-name>."
  exit 1
fi

# Set a default location if not provided
if [[ -z "$LOCATION" ]]; then
  LOCATION="canadacentral"
  echo "No location provided, defaulting to: $LOCATION"
fi

# --- VALIDATE RESOURCE GROUP EXISTS ---
echo "Validating that resource group '$RG_NAME' exists..."
if ! az group show --name "$RG_NAME" &>/dev/null; then
  echo "❌ Error: Resource group '$RG_NAME' does not exist."
  echo "Please create it first using step6_create_resource_group.sh"
  exit 1
fi
echo "✅ Resource group '$RG_NAME' exists."

# --- CHECK/CREATE STORAGE ACCOUNT ---
echo "Checking if storage account '$SA_NAME' exists..."
if az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" &>/dev/null; then
  echo "✅ Storage account '$SA_NAME' already exists, skipping creation."
  SA_JSON=$(az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --output json)
else
  echo "🆕 Creating storage account: $SA_NAME in resource group $RG_NAME at $LOCATION..."
  SA_JSON=$(az storage account create \
    --name "$SA_NAME" \
    --resource-group "$RG_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --min-tls-version TLS1_2 \
    --output json)
  echo "✅ Storage account '$SA_NAME' created successfully."
fi

SA_ID=$(echo "$SA_JSON" | jq -r '.id')
SA_LOCATION=$(echo "$SA_JSON" | jq -r '.primaryLocation')

# --- CHECK/CREATE BLOB CONTAINER ---
echo "Checking if blob container '$CONTAINER_NAME' exists..."
if az storage container show --name "$CONTAINER_NAME" --account-name "$SA_NAME" &>/dev/null; then
  echo "✅ Blob container '$CONTAINER_NAME' already exists, skipping creation."
else
  echo "🆕 Creating blob container: $CONTAINER_NAME in storage account $SA_NAME..."
  CONTAINER_JSON=$(az storage container create \
    --name "$CONTAINER_NAME" \
    --account-name "$SA_NAME" \
    --output json)
  echo "✅ Blob container '$CONTAINER_NAME' created successfully."
fi

# --- UPDATE FULL INVENTORY JSON ---
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[]}' > "$INVENTORY_FILE"
fi
# Ensure blobContainers array exists
jq 'if .blobContainers == null then .blobContainers = [] else . end' "$INVENTORY_FILE" > "$INVENTORY_FILE.tmp" && mv "$INVENTORY_FILE.tmp" "$INVENTORY_FILE"
TMP_FILE=$(mktemp)
jq --arg name "$SA_NAME" --arg id "$SA_ID" --arg location "$SA_LOCATION" '
  .storageAccounts |= map(select(.name != $name)) + [{"name":$name,"id":$id,"location":$location}]' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
TMP_FILE2=$(mktemp)
jq --arg name "$CONTAINER_NAME" --arg storageAccount "$SA_NAME" '
  .blobContainers |= map(select(.name != $name or .storageAccount != $storageAccount)) + [{"name":$name,"storageAccount":$storageAccount}]' "$INVENTORY_FILE" > "$TMP_FILE2" && mv "$TMP_FILE2" "$INVENTORY_FILE"
echo "✅ Storage account '$SA_NAME' and blob container '$CONTAINER_NAME' recorded in azure_full_inventory.json."

echo ""
echo "🎉 All required Terraform state backend resources are ready!"
echo "📋 Summary:"
echo "   • Storage Account: $SA_NAME"
echo "   • Resource Group: $RG_NAME" 
echo "   • Container: $CONTAINER_NAME"
echo "   • Location: $SA_LOCATION"
echo ""
echo "🔗 Next Steps:"
echo "   1. Verify resources in Azure Portal"
echo "   2. Run 'terraform init' to initialize remote backend"
echo "   3. Update terraform backend configuration if needed"
