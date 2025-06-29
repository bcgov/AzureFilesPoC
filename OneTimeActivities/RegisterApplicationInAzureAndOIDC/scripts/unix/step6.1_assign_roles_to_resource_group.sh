#!/usr/bin/env bash
# step6.1_assign_roles_to_resource_group.sh
#
# This script assigns the following roles to a specified service principal at the resource group scope:
#   - Storage Account Contributor
#   - ag-pssg-azure-files-poc-dev-role-assignment-writer (if present)
#   - Managed Identity Operator (cicd-tools group)
#   - Network Contributor (cicd-tools group)
#   - Virtual Machine Contributor (cicd-tools group)
#
# Usage:
#   bash step6.1_assign_roles_to_resource_group.sh --rgname <resource-group-name> --sp-object-id <service-principal-object-id> [--subscription-id <id>]
#
# Example:
#   bash step6.1_assign_roles_to_resource_group.sh --rgname rg-ag-pssg-azure-poc-dev --sp-object-id ace4c5df-cd88-44cb-90d5-77dac445f2ee
#
# This script will update the inventory file (.env/azure_full_inventory.json) with the current role assignments for the resource group.
#
# Role assignments applied (as of 2025-06-29):
#   Resource Group: rg-ag-pssg-azure-poc-dev
#     - ag-pssg-azure-files-poc-ServicePrincipal (ace4c5df-cd88-44cb-90d5-77dac445f2ee):
#         * Storage Account Contributor
#         * ag-pssg-azure-files-poc-dev-role-assignment-writer
#   Resource Group: rg-ag-pssg-tfstate-dev
#     - No direct role assignments
#   Resource Group: rg-ag-pssg-cicd-tools-dev
#     - ag-pssg-azure-files-poc-ServicePrincipal (ace4c5df-cd88-44cb-90d5-77dac445f2ee):
#         * Managed Identity Operator
#         * Network Contributor
#         * Virtual Machine Contributor
#
# Note: The service principal may also inherit additional roles at the subscription level (e.g., Reader, Monitoring Contributor, Private DNS Zone Contributor, etc.).
# These are not assigned by this script but may affect effective permissions.
#
# Inherited subscription-level roles for ag-pssg-azure-files-poc-ServicePrincipal (ace4c5df-cd88-44cb-90d5-77dac445f2ee):
#   * Reader
#   * [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#   * Monitoring Contributor
#   * Private DNS Zone Contributor
#   * Storage Account Contributor
#
# Update this section if you add or remove roles in the script logic or if assignments change in Azure.

set -euo pipefail

# --- ARGUMENT PARSING ---
RG_NAME=""
SP_OBJECT_ID=""
SUBSCRIPTION_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --rgname)
      RG_NAME="$2"; shift 2;;
    --sp-object-id)
      SP_OBJECT_ID="$2"; shift 2;;
    --subscription-id)
      SUBSCRIPTION_ID="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --rgname <resource-group-name> --sp-object-id <object-id> [--subscription-id <id>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$RG_NAME" || -z "$SP_OBJECT_ID" ]]; then
  echo "Error: --rgname and --sp-object-id are required."
  exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

# Assign Storage Account Contributor role
az role assignment create --assignee "$SP_OBJECT_ID" --role "Storage Account Contributor" --scope "$SCOPE" || true

# Assign custom role if present
if az role definition list --name "ag-pssg-azure-files-poc-dev-role-assignment-writer" | grep -q "name"; then
  az role assignment create --assignee "$SP_OBJECT_ID" --role "ag-pssg-azure-files-poc-dev-role-assignment-writer" --scope "$SCOPE" || true
fi

# Assign cicd-tools roles if in cicd-tools resource group
if [[ "$RG_NAME" == *"cicd-tools"* ]]; then
  az role assignment create --assignee "$SP_OBJECT_ID" --role "Managed Identity Operator" --scope "$SCOPE" || true
  az role assignment create --assignee "$SP_OBJECT_ID" --role "Network Contributor" --scope "$SCOPE" || true
  az role assignment create --assignee "$SP_OBJECT_ID" --role "Virtual Machine Contributor" --scope "$SCOPE" || true
fi

echo "✅ Roles assigned to $SP_OBJECT_ID at $RG_NAME."

# --- UPDATE FULL INVENTORY JSON ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"roleAssignments":[]}' > "$INVENTORY_FILE"
fi

# Fetch all role assignments for this resource group and principal
ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$SP_OBJECT_ID" --scope "$SCOPE" -o json)

# Update inventory file with new role assignments for this resource group
TMP_FILE=$(mktemp)
jq --arg rg "$RG_NAME" --argjson ras "$ROLE_ASSIGNMENTS" '
  .roleAssignments |= (map(select(.scope != $rg)) + ($ras // []))
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Inventory updated with role assignments for $RG_NAME."
