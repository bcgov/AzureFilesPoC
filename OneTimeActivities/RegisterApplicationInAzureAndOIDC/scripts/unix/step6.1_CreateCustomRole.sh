#!/usr/bin/env bash
# ================================================================
# step6.1_CreateCustomRole.sh
#
# SUMMARY:
#   This script creates or updates custom Azure roles from JSON definition files using the Azure CLI.
#   It should be run before assigning custom roles to service principals or users.
#
# WHAT IT DOES:
#   - Accepts one or more JSON files defining custom roles as arguments (or scans a default directory).
#   - Uses 'az role definition create' to create each custom role, or 'az role definition update' if the role already exists.
#   - Prints status and next steps for verification.
#
# USAGE:
#   bash step6.1_CreateCustomRole.sh <role-definition1.json> [<role-definition2.json> ...]
#   # Or, to create all roles in a directory:
#   bash step6.1_CreateCustomRole.sh OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/*.json
#
# PRECONDITIONS:
#   - Azure CLI is installed.
#   - You are logged in to Azure with sufficient permissions to create or update custom roles (run 'az login' if needed).
#   - Each JSON file must define a valid Azure custom role (see Azure docs for schema).
#
# INPUTS:
#   - One or more JSON files defining custom roles.
#
# OUTPUTS:
#   - Custom roles created or updated in Azure.
#   - Prints status for each role processed.
#
# NOTES:
#   - If a role already exists, the script will attempt to update it.
#   - If you have renamed a role, you may need to delete the old one manually using 'az role definition delete --name <old-role-name>'.
# INVENTORY: 
#  - Custom roles to be created:
#       - OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/ag-pssg-azure-files-poc-dev-resource-group-contributor.json
#       - OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/ag-pssg-azure-files-poc-dev-role-assignment-writer.json
# To see roles in subscription:  https://portal.azure.com/#@bcgov.onmicrosoft.com/resource/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/users
#        replace with your subscription ID
# if have problems with the script try to create manually via the Azure Portal:
#       -https://portal.azure.com/#@bcgov.onmicrosoft.com/resource/subscriptions/d321bcbe-c5e8-4830-901c-dab5fab3a834/users
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
