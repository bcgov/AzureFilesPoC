#!/usr/bin/env bash
# step8_create_storage_account.sh
# Creates a storage account using your own identity via Azure CLI.
# This is primarily for testing Azure Policy compliance locally, bypassing the CI/CD pipeline.
# It ensures the account is created with public network access disabled.

# example usage:
# ./OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step8_create_storage_account.sh \
#  --saname stagpssgazurepocdev01 \
#  --rgname rg-ag-pssg-azure-poc-dev

set -euo pipefail

# --- Resolve project root and config paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
TFVARS_FILE="$PROJECT_ROOT/terraform/environments/dev/terraform.tfvars" # Adjusted path to dev environment
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
LOCATION=""
RG_NAME=""
SA_NAME=""
TAGS_STRING_LITERALS=""
TAGS_JSON="{}"

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --saname)
      SA_NAME="$2"; shift 2;;
    --rgname)
      RG_NAME="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --saname <storage-account-name> --rgname <resource-group-name> [--location <location>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$SA_NAME" ]]; then
  echo "Error: Storage account name is required. Use --saname <storage-account-name>."
  exit 1
fi
if [[ -z "$RG_NAME" ]]; then
  echo "Error: Resource group name is required. Use --rgname <resource-group-name>."
  exit 1
fi

# --- LOAD LOCATION AND TAGS FROM TFVARS IF NOT PROVIDED ---
if [[ -z "$LOCATION" && -f "$TFVARS_FILE" ]]; then
  LOCATION=$(awk -F '="' '/^\s*azure_location\s*=\s*"/ {gsub(/"/,"",$2); gsub(/ /, "", $2); print $2}' "$TFVARS_FILE" | head -1)
fi
if [[ -f "$TFVARS_FILE" ]]; then
  FIRST=1
  in_tags=0
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*common_tags[[:space:]]*=[[:space:]]*\{ ]]; then
      in_tags=1; continue
    fi
    if [[ $in_tags -eq 1 ]]; then
      if [[ $line =~ ^[[:space:]]*\} ]]; then
        in_tags=0; continue
      fi
      tag_kv_regex='^[[:space:]]*"([^"]+)"[[:space:]]*=[[:space:]]*"([^"]*)"'
      if [[ $line =~ $tag_kv_regex ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        TAGS_STRING_LITERALS+="$key=$value "
        if [[ $FIRST -eq 0 ]]; then TAGS_JSON+=","; fi
        TAGS_JSON+="\"$key\":\"$value\""
        FIRST=0
      fi
    fi
  done < "$TFVARS_FILE"
  TAGS_JSON+="}"
  TAGS_STRING_LITERALS=$(echo "$TAGS_STRING_LITERALS" | sed 's/ *$//')
fi
if [[ -z "$LOCATION" ]]; then
  LOCATION="canadacentral" # Default if not found anywhere else
fi

# --- CREATE STORAGE ACCOUNT ---
echo "Attempting to create storage account: $SA_NAME in resource group $RG_NAME..."
echo "Location: $LOCATION"
echo "Public Network Access: Disabled"
echo "Tags: $TAGS_STRING_LITERALS"

# The core command to create the storage account in compliance with the policy.
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku "Standard_LRS" \
  --kind "StorageV2" \
  --access-tier "Hot" \
  --enable-large-file-share \
  --public-network-access "Disabled" \
  --min-tls-version "TLS1_2" \
  --allow-blob-public-access false \
  --tags $TAGS_STRING_LITERALS

echo "✅ Storage account '$SA_NAME' creation command executed."

# --- UPDATE FULL INVENTORY JSON ---
echo "Fetching storage account details to update inventory..."
SA_JSON=$(az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" -o json)
SA_ID=$(echo "$SA_JSON" | jq -r '.id')

mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[]}' > "$INVENTORY_FILE"
fi
# Add or update storage account entry
TMP_FILE=$(mktemp)
jq --arg name "$SA_NAME" --arg id "$SA_ID" '
  .storageAccounts |= map(select(.name != $name)) + [{"name":$name,"id":$id}]
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Storage account '$SA_NAME' recorded in azure_full_inventory.json."