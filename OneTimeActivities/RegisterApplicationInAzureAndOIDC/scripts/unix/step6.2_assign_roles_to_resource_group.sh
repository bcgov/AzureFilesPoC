#!/usr/bin/env bash
# ================================================================
# step6.2_assign_roles_to_resource_group.sh
#
# SUMMARY:
#   Assigns Azure RBAC roles to a service principal at the resource group scope.
#
# USAGE:
#   bash step6.2_assign_roles_to_resource_group.sh --rgname <resource-group-name> --assignee <object-id> --role "Role1" [--role "Role2" ...] [--subscription-id <id>]
#
# PRECONDITIONS:
#   - Azure CLI and jq installed and configured
#   - Authenticated to Azure (az login)
#   - Target resource groups exist
#   - Custom roles exist (created by step6.1_CreateCustomRole.sh)
#   - Service principal object ID is known
#
# POSTCONDITIONS:
#   - Role assignments created in Azure at specified resource group scope
#   - Inventory JSON updated with current role assignments
#
# ROLE ASSIGNMENT INVENTORY:
# =========================
# Resource Group: rg-<project-name>-<environment>
#   - <project-name>-ServicePrincipal (<service-principal-object-id>):
#       * Storage Account Contributor
#       * [<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer
#
# Resource Group: rg-<project-name>-tfstate-<environment>
#   - No direct role assignments (inherits subscription-level permissions)
#
# Resource Group: rg-<project-name>-<environment>-tools
#   - <project-name>-ServicePrincipal (<service-principal-object-id>):
#       * Managed Identity Operator
#       * Network Contributor
#       * Virtual Machine Contributor
#       * [<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer
#
# Resource Group: <ministry-code>-<environment>-networking
#   - <project-name>-ServicePrincipal (<service-principal-object-id>):
#       * Network Contributor
#       * [<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer
#
# Subscription-level roles (assigned separately by step2_grant_subscription_level_permissions.sh):
#   - <project-name>-ServicePrincipal (<service-principal-object-id>):
#       * Reader
#       * [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#       * Monitoring Contributor
#       * Private DNS Zone Contributor
#       * Storage Account Contributor
#
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
    
    # List all target resource groups (updated 2025-07-03)
    local resource_groups=(
        "rg-<project-name>-<environment>"
        "rg-<project-name>-tfstate-<environment>"
        "rg-<project-name>-<environment>-tools"
        "<ministry-code>-<environment>-networking"
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
