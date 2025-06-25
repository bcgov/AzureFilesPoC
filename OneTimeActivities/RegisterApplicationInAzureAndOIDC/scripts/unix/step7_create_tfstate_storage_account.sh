#!/usr/bin/env bash
# step7_create_tfstate_storage_account.sh
# Creates an Azure Storage Account and a Blob Container within it,
# specifically for storing Terraform state files.
# These resources must exist before 'terraform init' can be run successfully
# with a remote backend.
#
# Preconditions:
# 1. The Terraform resource group (e.g., 'rg-ag-pssg-tfstate-dev') must already exist in Azure.
#    - This resource group should be created using script 6: step6_create_resource_group.sh
# 2. Azure CLI must be installed and authenticated to the target subscription.
# 3. The authenticated Azure account must have permissions to create Storage Accounts
#    and Blob Containers within the specified resource group.
#
# Outputs:
# - This script will create both the storage account and blob container needed to use Terraform remote backend in GitHub Actions or local runs.
#
# Example Usage:
# bash ./step7_create_tfstate_storage_account.sh \
#   --rgname rg-ag-pssg-tfstate-dev \
#   --saname stagpssgtfstatedev01 \
#   --containername sc-ag-pssg-tfstate-dev \
#   --location canadacentral

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
      echo "Example: $0 --rgname rg-ag-pssg-tfstate-dev --saname stagpssgtfstatedev01 --containername sc-ag-pssg-tfstate-dev --location canadacentral"
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

# --- CREATE STORAGE ACCOUNT ---
echo "Creating storage account: $SA_NAME in resource group $RG_NAME at $LOCATION..."
SA_JSON=$(az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 \
  --output json)
SA_ID=$(echo "$SA_JSON" | jq -r '.id')
SA_LOCATION=$(echo "$SA_JSON" | jq -r '.primaryLocation')

echo "✅ Storage account '$SA_NAME' created."

# --- CREATE BLOB CONTAINER ---
echo "Creating blob container: $CONTAINER_NAME in storage account $SA_NAME..."
CONTAINER_JSON=$(az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$SA_NAME" \
  --output json)

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

echo "All required Terraform state backend resources are created."
