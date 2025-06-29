#!/usr/bin/env bash
# step9_create_subnet.sh
# This script creates a subnet in an existing VNet and records it in the inventory.
# It is reusable for creating additional subnets as needed.
#
# Example usage:
# bash step9_create_subnet.sh --vnetname d5007d-dev-vwan-spoke --vnetrg d5007d-dev-networking --subnetname snet-github-runners --addressprefix 10.46.73.16/28
#
# Parameters:
#   --vnetname      Name of the existing VNet
#   --vnetrg        Resource group of the VNet
#   --subnetname    Name for the new subnet
#   --addressprefix Address prefix for the subnet (e.g., 10.46.73.16/28)
#   [--nsg]         (Optional) NSG to associate
#   [--route-table] (Optional) Route table to associate
#
# Subnets created by script:
#  1. GitHub runners subnet (e.g., "snet-github-runners") 10.46.73.16/28
set -euo pipefail

# --- ARGUMENT PARSING ---
VNET_NAME=""
VNET_RG=""
SUBNET_NAME=""
ADDRESS_PREFIX=""
NSG_NAME=""
ROUTE_TABLE_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --vnetname)
      VNET_NAME="$2"; shift 2;;
    --vnetrg)
      VNET_RG="$2"; shift 2;;
    --subnetname)
      SUBNET_NAME="$2"; shift 2;;
    --addressprefix)
      ADDRESS_PREFIX="$2"; shift 2;;
    --nsg)
      NSG_NAME="$2"; shift 2;;
    --route-table)
      ROUTE_TABLE_NAME="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --vnetname <vnet-name> --vnetrg <vnet-resource-group> --subnetname <subnet-name> --addressprefix <address-prefix> [--nsg <nsg-name>] [--route-table <route-table-name>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$VNET_NAME" || -z "$VNET_RG" || -z "$SUBNET_NAME" || -z "$ADDRESS_PREFIX" ]]; then
  echo "Error: --vnetname, --vnetrg, --subnetname, and --addressprefix are required."; exit 1
fi

# --- CREATE SUBNET ---
echo "Creating subnet '$SUBNET_NAME' in VNet '$VNET_NAME' (RG: $VNET_RG) with address prefix $ADDRESS_PREFIX..."
CREATE_ARGS=(--name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" --address-prefixes "$ADDRESS_PREFIX")
if [[ -n "$NSG_NAME" ]]; then
  CREATE_ARGS+=(--network-security-group "$NSG_NAME")
fi
if [[ -n "$ROUTE_TABLE_NAME" ]]; then
  CREATE_ARGS+=(--route-table "$ROUTE_TABLE_NAME")
fi
az network vnet subnet create "${CREATE_ARGS[@]}"

# --- FETCH SUBNET DETAILS ---
SUBNET_JSON=$(az network vnet subnet show --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" -o json)
SUBNET_ID=$(echo "$SUBNET_JSON" | jq -r '.id')
ADDRESS_PREFIXES=$(echo "$SUBNET_JSON" | jq -r '.addressPrefix // .addressPrefixes | @csv')

# --- UPDATE FULL INVENTORY JSON ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[],"subnets":[]}' > "$INVENTORY_FILE"
fi
TMP_FILE=$(mktemp)
jq --arg name "$SUBNET_NAME" --arg id "$SUBNET_ID" --arg vnet "$VNET_NAME" --arg rg "$VNET_RG" --arg address "$ADDRESS_PREFIXES" '
  .subnets |= (map(select(.name != $name)) + [{"name":$name,"id":$id,"vnet":$vnet,"resourceGroup":$rg,"addressPrefixes":$address}])
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Subnet '$SUBNET_NAME' recorded in azure_full_inventory.json."

echo "Subnet creation complete."
