#!/usr/bin/env bash
# step6_create_resource_group.sh
# -----------------------------------------------------------------------------
# SUMMARY:
#   This script creates an Azure resource group for the project, as required by policy
#   (service principals and CI/CD pipelines are not permitted to create resource groups directly).
#   It is intended to be run by a human with sufficient permissions, and will:
#     - Create the resource group in the specified or default region
#     - Parse and apply tags from terraform.tfvars (if present)
#     - Update the local azure_full_inventory.json for tracking
#     - Assign required roles to the service principal at the resource group scope
#
#   Typical resource groups created:
#     1. resource_group = Main resource group for the Azure Files PoC (e.g., "rg-<project-name>-dev")
#     2. tfstate_rg  = Terraform state resource group (e.g., "rg-<project-name>-tfstate-dev")
#     3. cicd_resource_group_name =  CICD resource group (e.g., "rg-<project-name>-cicd-tools-dev")
#
# USAGE:
#   bash step6_create_resource_group.sh --rgname "rg-<project-name>-dev" --location "<azure-region>"
#
# PREREQUISITES:
#   - Azure CLI installed and authenticated
#   - jq installed for JSON processing
#   - terraform.tfvars and .env/azure-credentials.json present and up to date
#   - Sufficient permissions to create resource groups and assign roles
#
# IMPLEMENTATION NOTES:
#   - Idempotent: re-running will not create duplicate resource groups or role assignments
#   - Tags are parsed from terraform.tfvars for consistency with infrastructure as code
#   - All changes to inventory and credentials files are atomic (using temp files and mv)
#   - The script will prompt for missing service principal object ID if not found automatically
#   - For troubleshooting, check the output and the state of the inventory/credentials files after running
#   - If you add new tags or change the onboarding flow, update both the script and the documentation above
#
# NEXT STEPS:
#   1. Verify the resource group and role assignments in the Azure Portal
#   2. Mark this step as complete in the onboarding checklist or README.md
#   3. Continue with resource provisioning or validation as per your workflow
# -----------------------------------------------------------------------------

# --- Resolve project root and config paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
TFVARS_FILE="$PROJECT_ROOT/terraform/terraform.tfvars"
CREDENTIALS_FILE="$PROJECT_ROOT/.env/azure-credentials.json"
LOCATION=""
RG_NAME=""
TAGS_ARG=""
TAGS_JSON="{}"
TAGS_STRING_LITERALS=""

# --- ARGUMENT PARSING ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --rgname)
      RG_NAME="$2"; shift 2;;
    --location)
      LOCATION="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --rgname <resource-group-name> [--location <location>]"; exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$RG_NAME" ]]; then
  echo "Error: Resource group name is required. Use --rgname <resource-group-name>."; exit 1
fi

# --- LOAD LOCATION AND TAGS FROM TFVARS IF NOT PROVIDED ---
if [[ -z "$LOCATION" && -f "$TFVARS_FILE" ]]; then
  LOCATION=$(awk -F '="' '/^\s*dlocation\s*=\s*"/ {gsub(/"/,"",$2); gsub(/ /, "", $2); print $2}' "$TFVARS_FILE" | head -1)
fi
if [[ -f "$TFVARS_FILE" ]]; then
  # Parse common_tags block robustly (handle whitespace, comments, etc.)
  TAGS_ARG=""
  TAGS_JSON="{"
  TAGS_STRING_LITERALS=""
  FIRST=1
  in_tags=0
  while IFS= read -r line; do
    # Detect start of common_tags
    if [[ $line =~ ^[[:space:]]*common_tags[[:space:]]*=[[:space:]]*\{ ]]; then
      in_tags=1; continue
    fi
    if [[ $in_tags -eq 1 ]]; then
      # Detect end of block
      if [[ $line =~ ^[[:space:]]*\} ]]; then
        in_tags=0; continue
      fi
      # Parse key-value pairs
      tag_kv_regex='^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*=[[:space:]]*"([^"]*)"'
      if [[ $line =~ $tag_kv_regex ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        TAGS_ARG+="$key=$value "
        TAGS_STRING_LITERALS+="$key=$value "
        if [[ $FIRST -eq 0 ]]; then TAGS_JSON+=","; fi
        TAGS_JSON+="\"$key\":\"$value\""
        FIRST=0
      fi
    fi
  done < "$TFVARS_FILE"
  TAGS_JSON+="}"
  TAGS_STRING_LITERALS=$(echo "$TAGS_STRING_LITERALS" | sed 's/ *$//')
fi
if [[ -z "$LOCATION" ]]; then
  LOCATION="<default-azure-region>"
fi

# --- CREATE RESOURCE GROUP ---
echo "Creating resource group: $RG_NAME in $LOCATION..."
if [[ -n "$TAGS_STRING_LITERALS" ]]; then
  az group create --name "$RG_NAME" --location "$LOCATION" --tags $TAGS_STRING_LITERALS
else
  az group create --name "$RG_NAME" --location "$LOCATION"
fi

# --- FETCH RESOURCE GROUP DETAILS ---
RG_JSON=$(az group show --name "$RG_NAME" -o json)
RG_ID=$(echo "$RG_JSON" | jq -r '.id')
RG_LOCATION=$(echo "$RG_JSON" | jq -r '.location')

# --- UPDATE FULL INVENTORY JSON ---
INVENTORY_FILE="$PROJECT_ROOT/.env/azure_full_inventory.json"
mkdir -p "$PROJECT_ROOT/.env"
if [ ! -f "$INVENTORY_FILE" ]; then
  echo '{"resourceGroups":[],"storageAccounts":[],"blobContainers":[]}' > "$INVENTORY_FILE"
fi
# Add or update resource group entry
TMP_FILE=$(mktemp)
jq --arg name "$RG_NAME" --arg id "$RG_ID" --arg location "$RG_LOCATION" '
  .resourceGroups |= map(select(.name != $name)) + [{"name":$name,"id":$id,"location":$location}]
' "$INVENTORY_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$INVENTORY_FILE"
echo "✅ Resource group '$RG_NAME' recorded in azure_full_inventory.json."

# --- FETCH TAGS FROM AZURE ---
TAGS_JSON=$(az group show --name "$RG_NAME" --query tags -o json)

# Debug: Show the tags JSON fetched from Azure
if [[ -z "$TAGS_JSON" || "$TAGS_JSON" == "null" ]]; then
  echo "Warning: No tags found for resource group $RG_NAME. TAGS_JSON is empty or null."
else
  echo "Debug: TAGS_JSON from Azure: $TAGS_JSON"
fi

# --- UPDATE CREDENTIALS JSON ---
# Skipping tags update in credentials JSON as per user request
if [[ -f "$CREDENTIALS_FILE" ]]; then
  echo "✅ .env/azure-credentials.json found. No tag update performed."
else
  echo "Warning: Credentials file $CREDENTIALS_FILE not found. Skipping JSON update."
fi

# --- ASSIGN ROLES TO SERVICE PRINCIPAL OBJECT ID AT RESOURCE GROUP SCOPE ---
# Parse service_principal_id from tfvars if available
SERVICE_PRINCIPAL_ID=""
if [[ -f "$TFVARS_FILE" ]]; then
  SERVICE_PRINCIPAL_ID=$(awk -F '="' '/^\s*service_principal_id\s*=\s*"/ {gsub(/"/,"",$2); gsub(/ /, "", $2); print $2}' "$TFVARS_FILE" | head -1)
fi
# If still empty, try to look up by display name
if [[ -z "$SERVICE_PRINCIPAL_ID" ]]; then
  SERVICE_PRINCIPAL_ID=$(az ad sp list --display-name "<project-name>-ServicePrincipal" --query "[0].id" -o tsv)
fi
# If still empty, prompt the user
if [[ -z "$SERVICE_PRINCIPAL_ID" ]]; then
  read -rp "Enter the service principal (object) ID to assign roles to: " SERVICE_PRINCIPAL_ID
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

# Assign Storage Account Contributor role
echo "Assigning 'Storage Account Contributor' role to $SERVICE_PRINCIPAL_ID at resource group $RG_NAME..."
az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" --role "Storage Account Contributor" --scope "$SCOPE"
# syntax #
#az role assignment create --assignee <service-principal-object-id> --role "Storage Account Contributor" --scope <ID of the resource group>
#e.g. az role assignment create --assignee <service-principal-object-id> --role "Storage Account Contributor" --scope "/subscriptions/<subscription id>/resourceGroups/<resource group name>"

# Assign custom role (<project-name>-dev-role-assignment-writer)
echo "Assigning '<project-name>-dev-role-assignment-writer' role to $SERVICE_PRINCIPAL_ID at resource group $RG_NAME..."
az role assignment create --assignee "$SERVICE_PRINCIPAL_ID" --role "<project-name>-dev-role-assignment-writer" --scope "$SCOPE"

echo "✅ Resource group '$RG_NAME' created and roles assigned."

# --- OPTIONAL: LOOK UP SERVICE PRINCIPAL OBJECT ID BY NAME ---
# If you do not know the object ID, you can look it up with:
# az ad sp list --display-name "<project-name>-ServicePrincipal" --query "[0].objectId" -o tsv
# Or, if you know the appId:
# az ad sp show --id <appId> --query objectId -o tsv
#
# Example usage:
#   export SERVICE_PRINCIPAL_ID=$(az ad sp list --display-name "<project-name>-ServicePrincipal" --query "[0].objectId" -o tsv)
#   echo $SERVICE_PRINCIPAL_ID
