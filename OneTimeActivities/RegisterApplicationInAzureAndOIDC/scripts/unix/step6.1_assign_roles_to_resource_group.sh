#!/usr/bin/env bash
# step6.1_assign_roles_to_resource_group.sh
# DONT DELETE COMMENTS PLEASE
# This script assigns one or more specified roles to a service principal or user at the resource group scope.
#
# Usage:
#   bash step6.1_assign_roles_to_resource_group.sh --rgname <resource-group-name> --assignee <object-id> --role "Role1" [--role "Role2" ...] [--subscription-id <id>]
#
# Example:
#   bash step6.1_assign_roles_to_resource_group.sh --rgname rg-<project-name>-cicd-tools-dev --assignee <service-principal-object-id> --role "Virtual Machine Contributor" --role "Network Contributor" --role "Managed Identity Operator"
#
# This script will update the inventory file (.env/azure_full_inventory.json) with the current role assignments for the resource group.
#
# Note: The service principal may also inherit additional roles at the subscription level (e.g., Reader, Monitoring Contributor, Private DNS Zone Contributor, etc.).
# These are not assigned by this script but may affect effective permissions.
#
# Update this section if you add or remove roles in the script logic or if assignments change in Azure.
# # INVENTORY:
# Role assignments applied (as of 2025-06-29):
#   Resource Group: rg-<project-name>-dev
#     - <project-name>-ServicePrincipal (<client-id>):
#         * Storage Account Contributor
#         * <project-name>-dev-role-assignment-writer
#   Resource Group: rg-<project-name>-tfstate-dev
#     - No direct role assignments
#   Resource Group: rg-<project-name>-cicd-tools-dev
#    - <project-name>-ServicePrincipal (<client-id>):
#         * Managed Identity Operator
#         * Network Contributor
#         * Virtual Machine Contributor
#         * <project-name>-dev-role-assignment-writer
# Inherited subscription-level roles for <project-name>-ServicePrincipal (<client-id>):
#   * Reader
#   * [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#   * Monitoring Contributor
#   * Private DNS Zone Contributor
#   * Storage Account Contributor
#

set -euo pipefail

# --- ARGUMENT PARSING ---
RG_NAME=""
ASSIGNEE=""
SUBSCRIPTION_ID=""
ROLES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --rgname)
      RG_NAME="$2"; shift 2;;
    --sp-object-id|--assignee)
      ASSIGNEE="$2"; shift 2;;
    --subscription-id)
      SUBSCRIPTION_ID="$2"; shift 2;;
    --role)
      ROLES+=("$2"); shift 2;;
    -h|--help)
      echo "Usage: $0 --rgname <resource-group-name> --assignee <object-id> --role \"Role1\" [--role \"Role2\"] [--subscription-id <id>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
 done

if [[ -z "$RG_NAME" || -z "$ASSIGNEE" || ${#ROLES[@]} -eq 0 ]]; then
  echo "Error: --rgname, --assignee, and at least one --role are required."
  exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

for ROLE in "${ROLES[@]}"; do
  echo "Assigning role '$ROLE' to $ASSIGNEE at $SCOPE..."
  az role assignment create --assignee "$ASSIGNEE" --role "$ROLE" --scope "$SCOPE" || true
 done

echo "✅ Roles assigned to $ASSIGNEE at $RG_NAME."

# --- UPDATE FULL INVENTORY JSON ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"roleAssignments":[]}' > "$INVENTORY_FILE"
fi

# Fetch all role assignments for this resource group and assignee
ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$ASSIGNEE" --scope "$SCOPE" -o json)

# Update inventory file with new role assignments for this resource group
TMP_FILE=$(mktemp)
jq --arg rg "$RG_NAME" --argjson ras "$ROLE_ASSIGNMENTS" '
  .roleAssignments |= (map(select(.scope != $rg)) + ($ras // []))
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Inventory updated with role assignments for $RG_NAME."
