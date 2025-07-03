#!/usr/bin/env bash
# step10_create_nsg.sh
# This script creates a Network Security Group (NSG) in a specified resource group and location.
#
# ⚠️ In most modern BC Gov environments, you can use Terraform with the AzAPI provider in a GitHub Actions or Azure Pipelines CI/CD workflow to create and manage NSGs automatically.
#    If your pipeline/service principal has the right permissions, prefer managing NSGs in Terraform for full automation and auditability.
#    Use this script only if you are blocked by policy or permissions.
#
# POLICY & PERMISSION LIMITATIONS:
# - This script is only required if your service principal (used by Terraform or CI/CD) does NOT have sufficient permissions (e.g., Network Contributor) to create or update NSGs in Azure.
# - If Azure Policy restricts NSG creation or modification (e.g., only allowed via specific process or with required tags), you may need to run this script manually as a workaround.
# - For full automation and drift detection, ensure your service principal has the required roles and any necessary policy exemptions.
# - If you can manage NSGs in Terraform, prefer that approach for consistency and auditability.
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
#   2. dev_bastion_network_security_group = "nsg-bastion-vm-ag-pssg-azure-poc-dev-01"
#   3. dev_network_security_group = "nsg-ag-pssg-azure-poc-dev-01"
#
# NOTE: In most environments, NSGs can be created and managed by Terraform if the service principal has the Network Contributor role on the resource group.
# Prefer managing NSGs in Terraform for full automation and drift detection.

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

# --- CREATE OR UPDATE NSG (IDEMPOTENT) ---
EXISTS=0
if az network nsg show --name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
  EXISTS=1
fi

if [[ $EXISTS -eq 1 ]]; then
  echo "NSG '$NSG_NAME' already exists in resource group '$RESOURCE_GROUP'."
  if [[ -n "$TAGS" ]]; then
    echo "Updating tags for NSG '$NSG_NAME'..."
    az network nsg update --name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" --tags $TAGS
  fi
else
  echo "Creating NSG '$NSG_NAME' in resource group '$RESOURCE_GROUP' ($LOCATION)..."
  CREATE_ARGS=(--name "$NSG_NAME" --resource-group "$RESOURCE_GROUP" --location "$LOCATION")
  if [[ -n "$TAGS" ]]; then
    CREATE_ARGS+=(--tags $TAGS)
  fi
  az network nsg create "${CREATE_ARGS[@]}"
fi

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
