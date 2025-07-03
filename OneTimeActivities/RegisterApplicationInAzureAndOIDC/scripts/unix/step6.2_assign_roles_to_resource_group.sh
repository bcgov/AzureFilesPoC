#!/usr/bin/env bash
# ================================================================
# step6.2_assign_roles_to_resource_group.sh
#
# SUMMARY:
#   This script assigns one or more specified roles to a service principal or user at the resource group scope in Azure.
#   It is intended to be run after resource groups are created, to grant the necessary permissions for automation and operations.
#
# WHAT IT DOES:
#   - Accepts resource group name, assignee object ID, and one or more roles as arguments.
#   - Assigns each specified role to the assignee at the resource group scope using the Azure CLI.
#   - Updates the .env/azure_full_inventory.json file with the current role assignments for the resource group.
#   - Prints status and next steps.
#
# USAGE:
#      bash step6.2_assign_roles_to_resource_group.sh --rgname <resource-group-name> --assignee <object-id> --role "Role1" [--role "Role2" ...] [--subscription-id <id>]
#
# PRECONDITIONS:
#   - Azure CLI and jq are installed.
#   - You are logged in to Azure with sufficient permissions to assign roles (run 'az login' if needed).
#   - The target resource group(s) already exist in Azure.
#   - The assignee object ID (service principal or user) is known.
#   - all resource groups must already exist in Azure, created by step6_create_resource_group.sh.
#   - custom roles were already created in Azure, as specified in the inventory. with  step6.1_CreateCustomRole.sh
#       - OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/ag-pssg-azure-files-poc-dev-resource-group-contributor.json
#       - OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/ag-pssg-azure-files-poc-dev-role-assignment-writer.json
#
# INPUTS:
#   - Resource group name (via --rgname)
#   - Assignee object ID (via --assignee)
#   - One or more role names (via --role)
#   - Optional: subscription ID (via --subscription-id)
#
# OUTPUTS:
#   - Assigns the specified roles to the assignee at the resource group scope in Azure.
#   - Updates .env/azure_full_inventory.json with the new role assignments.
#   - Prints status and next steps for verification.
#
# NOTES:
#   -this script does not assign inherited subscription-level roles. It only manages resource group-level assignments.
#   - This script assigns one or more specified roles to a service principal or user at the resource group scope.
#   
# INVENTORY:
# Role assignments applied (as of 2025-06-29):
#   Resource Group: rg-<project-name>-dev
#     - <project-name>-ServicePrincipal (<client-id>):
#         * Storage Account Contributor
#         * [AG-PSSG-AZURE-FILES-POC-MANAGED]-dev-role-assignment-writer
#   Resource Group: rg-<project-name>-tfstate-dev
#     - No direct role assignments
#   Resource Group: rg-<project-name>-cicd-tools-dev
#    - <project-name>-ServicePrincipal (<client-id>):
#         * Managed Identity Operator
#         * Network Contributor
#         * Virtual Machine Contributor
#         * [AG-PSSG-AZURE-FILES-POC-MANAGED]-dev-role-assignment-writer
# Inherited subscription-level roles for <project-name>-ServicePrincipal (<client-id>):
#   those are assigned by step2_grant_subscription_level_permissions.sh
#   * Reader
#   * [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#   * Monitoring Contributor
#   * Private DNS Zone Contributor
#   * Storage Account Contributor
#================================================================

set -euo pipefail

# --- HELPER FUNCTIONS ---
show_resource_group_role_assignments() {
    local title="$1"
    local assignee="$2"
    local subscription_id="$3"
    
    echo "========== $title =========="
    echo "Resource Group | Role Name"
    echo "-------------- | ---------"
    
    # List all three target resource groups
    local resource_groups=(
        "rg-ag-pssg-azure-files-poc-dev"
        "rg-ag-pssg-azure-files-poc-tfstate-dev"
        "rg-ag-pssg-azure-files-poc-dev-tools"
    )
    
    for rg in "${resource_groups[@]}"; do
        local scope="/subscriptions/$subscription_id/resourceGroups/$rg"
        
        # Check if resource group exists first
        if ! az group show --name "$rg" &>/dev/null; then
            echo "$rg | (Resource group not found)"
            continue
        fi
        
        # Get role assignments for this assignee at this resource group scope
        local roles=$(az role assignment list --assignee "$assignee" --scope "$scope" --query "[].roleDefinitionName" -o tsv 2>/dev/null | sort || echo "")
        
        if [[ -z "$roles" ]]; then
            echo "$rg | (No role assignments)"
        else
            # Print each role on a separate line
            local first=true
            while IFS= read -r role; do
                if [[ -n "$role" ]]; then
                    if $first; then
                        echo "$rg | $role"
                        first=false
                    else
                        echo "$(printf "%*s" ${#rg} "") | $role"
                    fi
                fi
            done <<< "$roles"
        fi
    done
    echo ""
}

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

# --- SHOW ROLE ASSIGNMENTS BEFORE CHANGES ---
show_resource_group_role_assignments "Role Assignments BEFORE Changes" "$ASSIGNEE" "$SUBSCRIPTION_ID"

for ROLE in "${ROLES[@]}"; do
  echo "Assigning role '$ROLE' to $ASSIGNEE at $SCOPE..."
  az role assignment create --assignee "$ASSIGNEE" --role "$ROLE" --scope "$SCOPE" || true
 done

echo "✅ Roles assigned to $ASSIGNEE at $RG_NAME."

# --- SHOW ROLE ASSIGNMENTS AFTER CHANGES ---
show_resource_group_role_assignments "Role Assignments AFTER Changes" "$ASSIGNEE" "$SUBSCRIPTION_ID"

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
