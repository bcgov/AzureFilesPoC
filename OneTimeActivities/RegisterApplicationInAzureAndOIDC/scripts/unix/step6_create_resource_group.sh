#!/usr/bin/env bash
# step6_create_resource_group.sh
#
# NOTE: As of June 2025, if you have created and assigned a custom role with 
#       sufficient permissions (e.g., Contributor or a custom role allowing resource group 
#       creation), this script is no longer required for BC Gov Azure onboarding. 
#       Resource group creation via automation is permitted if your identity has 
#       the necessary permissions. This script is retained for reference and manual 
#       onboarding scenarios.
#
# Only creates the resource group and updates .env/azure-credentials.json with its metadata and tags.

set -euo pipefail

# --- Resolve project root and config paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
TFVARS_FILE="$PROJECT_ROOT/terraform/validation/terraform.tfvars"
CREDENTIALS_FILE="$PROJECT_ROOT/.env/azure-credentials.json"
LOCATION=""
RG_NAME=""
TAGS_ARG=""
TAGS_JSON="{}"
TAGS_STRING_LITERALS=""

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --rgname)
      RG_NAME="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --rgname <resource-group-name> [--location <location>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$RG_NAME" ]]; then
  echo "Error: Resource group name is required. Use --rgname <resource-group-name>."; exit 1
fi

# --- LOAD LOCATION AND TAGS FROM TFVARS IF NOT PROVIDED ---
if [[ -z "$LOCATION" && -f "$TFVARS_FILE" ]]; then
  LOCATION=$(awk -F '="' '/^\s*dev_location\s*=\s*"/ {gsub(/"/,"",$2); gsub(/ /, "", $2); print $2}' "$TFVARS_FILE" | head -1)
fi
if [[ -f "$TFVARS_FILE" ]]; then
  # Parse common_tags block robustly (handle whitespace, comments, etc.)
  TAGS_ARG=""
  TAGS_JSON="{"
  TAGS_STRING_LITERALS=""
  FIRST=1
  in_tags=0
  while IFS= read -r line; do
    # Detect start of common_tags
    if [[ $line =~ ^[[:space:]]*common_tags[[:space:]]*=[[:space:]]*\{ ]]; then
      in_tags=1; continue
    fi
    if [[ $in_tags -eq 1 ]]; then
      # Detect end of block
      if [[ $line =~ ^[[:space:]]*\} ]]; then
        in_tags=0; continue
      fi
      # Parse key-value pairs
      tag_kv_regex='^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*"([^"]*)"'
      if [[ $line =~ $tag_kv_regex ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        TAGS_ARG+="$key=$value "
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
  LOCATION="canadacentral"
fi

# --- CREATE RESOURCE GROUP ---
echo "Creating resource group: $RG_NAME in $LOCATION..."
if [[ -n "$TAGS_STRING_LITERALS" ]]; then
  az group create --name "$RG_NAME" --location "$LOCATION" --tags $TAGS_STRING_LITERALS
else
  az group create --name "$RG_NAME" --location "$LOCATION"
fi

# --- FETCH RESOURCE GROUP DETAILS ---
RG_JSON=$(az group show --name "$RG_NAME" -o json)
RG_ID=$(echo "$RG_JSON" | jq -r '.id')
RG_LOCATION=$(echo "$RG_JSON" | jq -r '.location')

# --- UPDATE FULL INVENTORY JSON ---
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[]}' > "$INVENTORY_FILE"
fi
# Add or update resource group entry
TMP_FILE=$(mktemp)
jq --arg name "$RG_NAME" --arg id "$RG_ID" --arg location "$RG_LOCATION" '
  .resourceGroups |= map(select(.name != $name)) + [{"name":$name,"id":$id,"location":$location}]
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Resource group '$RG_NAME' recorded in azure_full_inventory.json."

# --- FETCH TAGS FROM AZURE ---
TAGS_JSON=$(az group show --name "$RG_NAME" --query tags -o json)

# Debug: Show the tags JSON fetched from Azure
if [[ -z "$TAGS_JSON" || "$TAGS_JSON" == "null" ]]; then
  echo "Warning: No tags found for resource group $RG_NAME. TAGS_JSON is empty or null."
else
  echo "Debug: TAGS_JSON from Azure: $TAGS_JSON"
fi

# --- UPDATE CREDENTIALS JSON ---
# Skipping tags update in credentials JSON as per user request
if [[ -f "$CREDENTIALS_FILE" ]]; then
  echo "✅ .env/azure-credentials.json found. No tag update performed."
else
  echo "Warning: Credentials file $CREDENTIALS_FILE not found. Skipping JSON update."
fi

echo "✅ Resource group '$RG_NAME' created."
