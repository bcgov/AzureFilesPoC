#!/usr/bin/env bash
# step12_import_existing_resources.sh
#
# One-time script to import pre-existing Azure resources into Terraform state.
# This is required for resources that were created outside of Terraform but must now be managed by Terraform (e.g., subnet/NSG associations).
#
# Usage:
#   Run from your environment directory (e.g., terraform/environments/cicd):
#   ./step12_import_existing_resources.sh --subscription-id <id> --vnet-name <name> --vnet-rg <rg> --subnet-name <name>
#
# This script will ensure you are logged in to Azure CLI before running the import.
#
# Note: During the import, Terraform may prompt you for the value of var.admin_ssh_key_public (your SSH public key).
# You can copy it by running:
#   cat ~/.ssh/id_rsa.pub
# or the path to your public key file.

set -euo pipefail

usage() {
  echo "Usage: $0 --subscription-id <id> --vnet-name <name> --vnet-rg <rg> --subnet-name <name>"
  echo "  This script will ensure you are logged in to Azure CLI before running the import."
  echo "  If prompted for your SSH public key, use: cat ~/.ssh/id_rsa.pub"
  exit 1
}

# Parse parameters
if [[ $# -ne 8 ]]; then
  usage
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --subscription-id)
      SUBSCRIPTION_ID="$2"; shift 2;;
    --vnet-name)
      VNET_NAME="$2"; shift 2;;
    --vnet-rg)
      VNET_RG="$2"; shift 2;;
    --subnet-name)
      SUBNET_NAME="$2"; shift 2;;
    -h|--help)
      usage;;
    *)
      echo "Unknown argument: $1"; usage;;
  esac
done

# Validate
if [[ -z "$SUBSCRIPTION_ID" || -z "$VNET_NAME" || -z "$VNET_RG" || -z "$SUBNET_NAME" ]]; then
  echo "ERROR: All parameters are required."
  usage
fi

# Ensure Azure CLI login is valid
if ! az account show > /dev/null 2>&1; then
  echo "Azure CLI not logged in. Running 'az login --scope https://graph.microsoft.com/.default'..."
  az login --scope https://graph.microsoft.com/.default
fi

echo "Azure CLI login verified. Proceeding with import."

TF_RESOURCE="azurerm_subnet_network_security_group_association.runner_nsg_assoc"
AZURE_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_RG/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"

# Check if the resource is already in state
if terraform state list | grep -q "^$TF_RESOURCE$"; then
  echo "Resource $TF_RESOURCE is already managed by Terraform. Removing from state before re-importing..."
  terraform state rm "$TF_RESOURCE"
fi

echo "Importing $TF_RESOURCE from $AZURE_RESOURCE_ID ..."
terraform import "$TF_RESOURCE" "$AZURE_RESOURCE_ID"

echo "Import complete. Review the Terraform state and re-run 'terraform plan'."
