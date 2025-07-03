#!/usr/bin/env bash
# step9_create_subnet.sh
# NOTE: This script is only required if your service principal does NOT have permission to create subnets with NSG association in a single step (required by strict Azure policy).
#
# ⚠️ In most modern BC Gov environments, you can use Terraform with the AzAPI provider in a GitHub Actions or Azure Pipelines CI/CD workflow to create subnets with NSG association automatically.
#    If your pipeline/service principal has the right permissions, prefer managing subnets in Terraform for full automation and auditability.
#    Use this script only if you are blocked by policy or permissions.
#
# If you do not have the required permissions or cannot use AzAPI, use this script for manual onboarding.
#
# This script creates a subnet in an existing VNet and records it in the inventory.
# It is reusable for creating additional subnets as needed.
#
# Example usage:
# bash step9_create_subnet.sh --vnetname d5007d-dev-vwan-spoke --vnetrg d5007d-dev-networking --subnetname AzureBastionSubnet --addressprefix 10.46.73.64/26 --nsg nsg-bastion-vm-ag-pssg-azure-poc-dev-01
#
# Parameters:
#   --vnetname      Name of the existing VNet
#   --vnetrg        Resource group of the VNet
#   --subnetname    Name for the new subnet (e.g., AzureBastionSubnet)
#   --addressprefix Address prefix for the subnet (e.g., 10.46.73.64/26)
#   [--nsg]         (Optional, but required by policy for Bastion) NSG to associate (e.g., nsg-bastion-vm-ag-pssg-azure-poc-dev-01)
#   [--route-table] (Optional) Route table to associate
#
# Subnets created by script:
#  1. Bastion subnet ("AzureBastionSubnet") 10.46.73.64/26
#  2. GitHub runners subnet (e.g., "snet-github-runners") 10.46.73.16/28
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

# --- CHECK IF SUBNET ALREADY EXISTS ---
EXISTING_SUBNET=$(az network vnet subnet show --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" -o json 2>/dev/null || true)
if [[ -n "$EXISTING_SUBNET" && "$EXISTING_SUBNET" != "" ]]; then
  EXISTING_PREFIX=$(echo "$EXISTING_SUBNET" | jq -r '.addressPrefix // .addressPrefixes[0]')
  EXISTING_NSG_ID=$(echo "$EXISTING_SUBNET" | jq -r '.networkSecurityGroup.id // empty')
  NSG_ID=""
  if [[ -n "$NSG_NAME" ]]; then
    NSG_ID=$(az network nsg show --name "$NSG_NAME" --resource-group "$VNET_RG" -o tsv --query id 2>/dev/null || true)
    if [[ -z "$NSG_ID" ]]; then
      echo "Error: NSG '$NSG_NAME' does not exist in resource group '$VNET_RG'. Please create it first."; exit 1
    fi
  fi
  if [[ "$EXISTING_PREFIX" == "$ADDRESS_PREFIX" ]]; then
    # Check NSG association
    if [[ -n "$NSG_NAME" && "$EXISTING_NSG_ID" != "$NSG_ID" ]]; then
      echo "Updating NSG association for subnet '$SUBNET_NAME'..."
      az network vnet subnet update --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" --network-security-group "$NSG_NAME"
    else
      echo "Subnet '$SUBNET_NAME' already exists in VNet '$VNET_NAME' with the same address prefix ($ADDRESS_PREFIX) and correct NSG association. Skipping creation."
    fi
  else
    echo "Error: Subnet '$SUBNET_NAME' already exists but with a different address prefix ($EXISTING_PREFIX). Please review and delete or update as needed."
    exit 1
  fi
else
  # --- CREATE SUBNET ---
  echo "Creating subnet '$SUBNET_NAME' in VNet '$VNET_NAME' (RG: $VNET_RG) with address prefix $ADDRESS_PREFIX..."
  CREATE_ARGS=(--name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" --address-prefixes "$ADDRESS_PREFIX")
  if [[ -n "$NSG_NAME" ]]; then
    # Check NSG exists
    NSG_ID=$(az network nsg show --name "$NSG_NAME" --resource-group "$VNET_RG" -o tsv --query id 2>/dev/null || true)
    if [[ -z "$NSG_ID" ]]; then
      echo "Error: NSG '$NSG_NAME' does not exist in resource group '$VNET_RG'. Please create it first."; exit 1
    fi
    CREATE_ARGS+=(--network-security-group "$NSG_NAME")
  fi
  if [[ -n "$ROUTE_TABLE_NAME" ]]; then
    CREATE_ARGS+=(--route-table "$ROUTE_TABLE_NAME")
  fi
  az network vnet subnet create "${CREATE_ARGS[@]}"
fi

# --- FETCH SUBNET DETAILS ---
SUBNET_JSON=$(az network vnet subnet show --name "$SUBNET_NAME" --vnet-name "$VNET_NAME" --resource-group "$VNET_RG" -o json)
SUBNET_ID=$(echo "$SUBNET_JSON" | jq -r '.id')
ADDRESS_PREFIXES=$(echo "$SUBNET_JSON" | jq -r 'if .addressPrefixes then .addressPrefixes | @csv else .addressPrefix end')

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
