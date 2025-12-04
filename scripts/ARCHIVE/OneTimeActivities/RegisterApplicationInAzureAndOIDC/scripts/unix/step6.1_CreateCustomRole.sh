#!/usr/bin/env bash
# ================================================================
# step6.1_CreateCustomRole.sh
#
# SUMMARY:
#   Creates or updates custom Azure roles from JSON definition files.
#
# USAGE:
#   bash step6.1_CreateCustomRole.sh <role-definition1.json> [<role-definition2.json> ...]
#
# PRECONDITIONS:
#   - Azure CLI installed and configured
#   - Authenticated to Azure with role creation permissions (az login)
#   - JSON files define valid Azure custom roles
#
# POSTCONDITIONS:
#   - Custom roles created or updated in Azure
#   - Status printed for each role processed
#
# CUSTOM ROLE INVENTORY:
# =====================
# Custom roles to be created:
#
# 1. [<team-name>-<project-name>-MANAGED]-<environment>-resource-group-contributor
#    - Description: Allows writing and reading resource groups for automation
#    - Actions: Microsoft.Resources/subscriptions/resourceGroups/write, read, delete
#    - File: <team-name>-<project-name>-MANAGED-<environment>-resource-group-contributor.json
#
# 2. [<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer
#    - Description: Allows writing and reading role assignments for automation
#    - Actions: Microsoft.Authorization/roleAssignments/read, write, delete
#    - File: <team-name>-<project-name>-MANAGED-<environment>-role-assignment-writer.json
#
# To view roles: Azure Portal > Subscriptions > <subscription-id> > Access control (IAM) > Roles > Custom
# ================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <role-definition1.json> [<role-definition2.json> ...]"
  exit 1
fi

# --- LIST CUSTOM ROLES BEFORE CREATION/UPDATE ---
echo "Custom roles in the subscription BEFORE creation/update:" 
az role definition list --custom-role-only true --query "[].{Name:roleName, Id:id}" -o table

for ROLE_DEF in "$@"; do
  if [[ ! -f "$ROLE_DEF" ]]; then
    echo "❌ Error: File not found: $ROLE_DEF"
    continue
  fi
  
  # Validate JSON and extract role name
  if ! jq empty "$ROLE_DEF" 2>/dev/null; then
    echo "❌ Error: Invalid JSON in file: $ROLE_DEF"
    continue
  fi
  
  # Try both JSON formats: direct format and properties format
  ROLE_NAME=$(jq -r '.Name // .properties.roleName // empty' "$ROLE_DEF")
  if [[ -z "$ROLE_NAME" ]]; then
    echo "❌ Error: Role name not found in file: $ROLE_DEF"
    echo "   Expected: .Name or .properties.roleName"
    continue
  fi
  
  echo "Processing custom role: $ROLE_NAME from $ROLE_DEF"
  
  # Check if role already exists
  EXISTING_ROLE=$(az role definition list --name "$ROLE_NAME" --query "[0].id" -o tsv 2>/dev/null || echo "")
  
  if [[ -n "$EXISTING_ROLE" ]]; then
    echo "🔄 Role '$ROLE_NAME' already exists. Updating..."
    if az role definition update --role-definition "$ROLE_DEF"; then
      echo "✅ Role '$ROLE_NAME' updated successfully."
    else
      echo "❌ Failed to update role '$ROLE_NAME'"
    fi
  else
    echo "🆕 Creating new role '$ROLE_NAME'..."
    if az role definition create --role-definition "$ROLE_DEF"; then
      echo "✅ Role '$ROLE_NAME' created successfully."
    else
      echo "❌ Failed to create role '$ROLE_NAME'"
    fi
  fi
  echo "---"
done

# --- LIST CUSTOM ROLES AFTER CREATION/UPDATE ---
echo "Custom roles in the subscription AFTER creation/update:" 
az role definition list --custom-role-only true --query "[].{Name:roleName, Id:id}" -o table

echo "✅ Custom role creation/update complete."
