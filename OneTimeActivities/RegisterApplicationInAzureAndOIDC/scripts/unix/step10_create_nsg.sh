#!/usr/bin/env bash
# step10_create_nsg.sh
# This script creates a Network Security Group (NSG) in a specified resource group and location.
# It is reusable for creating additional NSGs as needed and records them in the inventory.
#
# Example usage:
# bash step10_create_nsg.sh --nsgname nsg-github-runners --rg d5007d-dev-networking --location canadacentral
#
# Parameters:
#   --nsgname   Name for the new NSG (e.g., nsg-github-runners)
#   --rg        Resource group for the NSG
#   --location  Azure region (e.g., canadacentral)
#   [--tags]    (Optional) Tags in key=value format, space separated (e.g., "env=dev project=ag-pssg-azure-files-poc")
#
# NSGs created by script:
#   1. GitHub runners NSG (e.g., "nsg-github-runners")
set -euo pipefail

# --- ARGUMENT PARSING ---
NSG_NAME=""
RESOURCE_GROUP=""
LOCATION=""
TAGS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --nsgname)
      NSG_NAME="$2"; shift 2;;
    --rg)
      RESOURCE_GROUP="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    --tags)
      TAGS="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --nsgname <nsg-name> --rg <resource-group> --location <location> [--tags 'key=value ...']"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$NSG_NAME" || -z "$RESOURCE_GROUP" || -z "$LOCATION" ]]; then
  echo "Error: --nsgname, --rg, and --location are required."; exit 1
fi

# --- CREATE NSG ---
echo "Creating NSG '$NSG_NAME' in resource group '$RESOURCE_GROUP' ($LOCATION)..."
CREATE_ARGS=(--name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION")
if [[ -n "$TAGS" ]]; then
  CREATE_ARGS+=(--tags $TAGS)
fi
az network nsg create "${CREATE_ARGS[@]}"

# --- FETCH NSG DETAILS ---
NSG_JSON=$(az network nsg show --name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" -o json)
NSG_ID=$(echo "$NSG_JSON" | jq -r '.id')

# --- UPDATE FULL INVENTORY JSON ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[],"subnets":[],"networkSecurityGroups":[]}' > "$INVENTORY_FILE"
fi
TMP_FILE=$(mktemp)
jq --arg name "$NSG_NAME" --arg id "$NSG_ID" --arg rg "$RESOURCE_GROUP" --arg location "$LOCATION" '
  .networkSecurityGroups |= (map(select(.name != $name)) + [{"name":$name,"id":$id,"resourceGroup":$rg,"location":$location}])
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ NSG '$NSG_NAME' recorded in azure_full_inventory.json."

echo "NSG creation complete."
