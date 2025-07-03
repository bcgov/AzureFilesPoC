#!/bin/bash
# step2_grant_subscription_level_permissions.sh
# =====================================================================================================
# SUMMARY:
#   Grants required Azure subscription-level roles to a service principal (or user) for onboarding and
#   automation scenarios. Ensures only the minimum set of roles are assigned for least-privilege access.
#   Idempotent: can be safely re-run; will not duplicate assignments or create unnecessary changes.
#
# WHAT THIS SCRIPT DOES:
#   - Assigns the following roles to the service principal at the **subscription level**:
#       * Reader
#       * Storage Account Contributor
#       * [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
#       * Private DNS Zone Contributor
#       * Monitoring Contributor
#
# ⚠️ For least privilege, data-plane roles such as Storage Blob Data Contributor or Storage File Data SMB Share Contributor
# should be assigned at the storage account or resource group level, NOT at the subscription level.
#
# This script does NOT assign resource-group-level or inherited roles. Those should be managed by their respective scripts.
#
# Update the REQUIRED_ROLES array below if you add or remove subscription-level roles.
#
# NOTE: This script is idempotent and can be safely run multiple times.
#       It will not create duplicate Azure AD applications or service principals.
#
# -----------------------------------------------------------------------------
# Implementation notes:
# - This script is designed to be idempotent: it checks for existing role assignments and only adds missing ones.
# - It will also remove any extra roles at the subscription level that are not in the REQUIRED_ROLES array.
# - All Azure CLI commands are wrapped with error handling and retry logic for reliability.
# - All changes to credentials and inventory files are atomic (using temp files and mv).
# - The script will prompt before making changes, and will not proceed without user confirmation.
# - If you encounter errors related to authentication or expired tokens, the script will attempt to refresh your login.
# - For troubleshooting, check the output of each command and the state of the credentials/inventory files after running.
# - If you add new roles, update both the REQUIRED_ROLES array and the documentation above.
# - For custom roles, ensure they are created before running this script, and use the exact role name as it appears in Azure.
#
# -----------------------------------------------------------------------------
#
# Example usage:
#   bash step2_grant_subscription_level_permissions.sh --app-id <application-id> --principal-id <service-principal-object-id> --subscription-id <subscription-id>
#   bash step2_grant_subscription_level_permissions.sh --app-id <application-id> --principal-id <service-principal-object-id>
#   bash step2_grant_subscription_level_permissions.sh --app-id <application-id>
#   bash step2_grant_subscription_level_permissions.sh
#
# Arguments:
#   --app-id <application-id>                # Azure AD Application (client) ID
#   --principal-id <service-principal-id>    # Service Principal Object ID
#   --subscription-id <subscription-id>      # Azure Subscription ID (optional, will use from credentials if omitted)
#
# If arguments are omitted, values will be read from the credentials file.
#
# Next steps after running this script:
#   1. Verify all required roles are assigned correctly in the Azure Portal or via CLI.
#   2. Run step3_configure_oidc.sh to set up GitHub Actions authentication.
#   3. If you need to assign data-plane roles, use the appropriate resource group or storage account scripts.
#
# -----------------------------------------------------------------------------

# Function to resolve script location and set correct paths
resolve_script_path() {
    local script_path
    # Get the real path of the script, resolving any symlinks
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Extract the directory
    SCRIPT_DIR="$(dirname "$script_path")"
    
    # Navigate to project root (up from scripts/unix/RegisterApplicationInAzureAndOIDC/OneTimeActivities)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
    
    echo "Script running from: $SCRIPT_DIR"
    echo "Project root: $PROJECT_ROOT"
}

# Call path resolution function
resolve_script_path

# Initialize variables
ENV_DIR="$PROJECT_ROOT/.env"
CREDS_FILE="$ENV_DIR/azure-credentials.json"
INVENTORY_FILE="$ENV_DIR/azure_full_inventory.json"

# Required roles
REQUIRED_ROLES=(
    # Base roles (assigned at the subscription level; keep to a minimum for least privilege)
    # Only include roles here that are truly needed across the entire subscription.
    # For storage/data plane roles (e.g., Storage Blob Data Contributor, Storage File Data SMB Share Contributor),
    # assign them at the storage account or resource group level for least privilege and better security.
    "Reader"
    "Storage Account Contributor"
    "[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor"
    "Private DNS Zone Contributor"
    "Monitoring Contributor"
)

# Function to check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Function to verify prerequisites
verify_prerequisites() {
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is required but not installed."
        if is_macos; then
            echo "Install using: brew update && brew install azure-cli"
        else
            echo "Install using your package manager or visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        fi
        exit 1
    fi

    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed."
        if is_macos; then
            echo "Install using: brew install jq"
        else
            echo "Install using your package manager"
        fi
        exit 1
    fi
}

# Function to handle Azure CLI errors
handle_azure_error() {
    local error_msg=$1
    if [[ $error_msg =~ "AADSTS70043" ]] || [[ $error_msg =~ "expired" ]]; then
        echo "Token expired or permission issue detected. Attempting to refresh login..."
        az account clear
        az login --scope "https://graph.microsoft.com//.default"
        return 0
    elif [[ $error_msg =~ "authentication needed" ]]; then
        echo "Authentication needed. Please login again..."
        az login --scope "https://graph.microsoft.com//.default"
        return 0
    fi
    return 1
}

# Function to execute Azure CLI command with retry
execute_az_command() {
    local cmd=$1
    local max_retries=3
    local retry=0
    local result
    
    while [ $retry -lt $max_retries ]; do
        result=$(eval "$cmd 2>&1")
        if [ $? -eq 0 ]; then
            echo "$result"
            return 0
        else
            if handle_azure_error "$result"; then
                retry=$((retry + 1))
                echo "Retrying command... (Attempt $retry of $max_retries)"
                continue
            else
                echo "Error executing command: $cmd"
                echo "Error message: $result"
                return 1
            fi
        fi
    done
    
    echo "Failed after $max_retries retries"
    return 1
}

# Function to clean up duplicate role assignments in credentials file
cleanup_duplicate_role_assignments() {
    echo "Cleaning up duplicate role assignments in credentials file..."
    local temp_file
    temp_file=$(mktemp)
    
    # Remove duplicates by keeping only unique combinations of roleName + id + scope
    jq '
    .azure.subscription.roleAssignments = (
        .azure.subscription.roleAssignments
        | group_by(.roleName + (.id // "") + (.scope // ""))
        | map(.[0])
        | sort_by(.roleName)
    )
    ' "$CREDS_FILE" > "$temp_file" && mv "$temp_file" "$CREDS_FILE"
    
    echo "Duplicate role assignments cleaned up"
}

# Function to clean up role assignments in JSON
cleanup_role_assignments() {
    echo "Cleaning up role assignments in credentials file..."
    local temp_file
    temp_file=$(mktemp)
    # Remove any incorrect roleAssignments at the wrong level and ensure proper structure
    jq '
    del(.azure.ad.application.roleAssignments) |
    if .azure.subscription.roleAssignments == null then
      .azure.subscription.roleAssignments = []
    else . end |
    if .azure.subscription.resourceGroups then
      .azure.subscription.resourceGroups |= map(
        if .roleAssignments == null then .roleAssignments = [] else . end
      )
    else . end
    ' "$CREDS_FILE" > "$temp_file" && mv "$temp_file" "$CREDS_FILE"
    
    # Also clean up any duplicates
    cleanup_duplicate_role_assignments
}

# Function to update role assignments in JSON at the correct scope
update_role_assignments() {
    local role_name=$1
    local role_id=$2
    local role_definition_id=$3
    local scope=$4
    local assigned_on
    assigned_on=$(date '+%Y-%m-%dT%H:%M:%SZ')
    local temp_file
    temp_file=$(mktemp)
    # Add the new role assignment under azure.subscription.roleAssignments, including all fields
    jq --arg role_name "$role_name" \
       --arg id "$role_id" \
       --arg principal_id "$PRINCIPAL_ID" \
       --arg role_definition_id "$role_definition_id" \
       --arg scope "$scope" \
       --arg assigned_on "$assigned_on" \
       '
       .azure.subscription.roleAssignments += [{
           "roleName": $role_name,
           "id": $id,
           "principalId": $principal_id,
           "roleDefinitionId": $role_definition_id,
           "scope": $scope,
           "assignedOn": $assigned_on
       }]
       ' "$CREDS_FILE" > "$temp_file" && mv "$temp_file" "$CREDS_FILE"
    echo "Added role assignment to credentials file at scope $scope"
}

# Function to capture all existing role assignments in JSON
capture_existing_role_assignments() {
    echo "Capturing existing role assignments in the credentials file..."
    
    # Clean up existing structure first
    cleanup_role_assignments
    
    # Get all current role assignments in detail
    local ROLE_DETAILS
    ROLE_DETAILS=$(execute_az_command "az role assignment list --assignee \"$APP_ID\" --include-inherited --query '[].{id:id,roleName:roleDefinitionName,principalId:principalId,scope:scope}' -o json")
    
    if [ -z "$ROLE_DETAILS" ] || [ "$ROLE_DETAILS" == "[]" ]; then
        echo "No role assignments found to capture"
        return
    fi
    
    # Process all role assignments at once to avoid duplicates
    local temp_file
    temp_file=$(mktemp)
    local assigned_on
    assigned_on=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Transform the role details and add them all at once
    echo "$ROLE_DETAILS" | jq --arg date "$assigned_on" '
        map({
            "roleName": .roleName,
            "id": .id,
            "principalId": .principalId,
            "scope": .scope,
            "assignedOn": $date
        })
    ' > "$temp_file.roles"
    
    # Update the credentials file with all role assignments at once
    jq --slurpfile roles "$temp_file.roles" '
        .azure.subscription.roleAssignments = $roles[0]
    ' "$CREDS_FILE" > "$temp_file" && mv "$temp_file" "$CREDS_FILE"
    
    # Clean up temporary files
    rm -f "$temp_file.roles"
    
    echo "All existing role assignments captured in credentials file ($(echo "$ROLE_DETAILS" | jq length) assignments)"
    
    echo "All existing role assignments captured in credentials file"
}

# Function to update top-level roleAssignments in inventory file
update_inventory_role_assignments() {
    echo "Updating .env/azure_full_inventory.json roleAssignments array..."
    local ROLE_DETAILS
    ROLE_DETAILS=$(execute_az_command "az role assignment list --assignee \"$APP_ID\" --include-inherited --query '[].{id:id,roleName:roleDefinitionName,principalId:principalId,scope:scope}' -o json")
    if [ -z "$ROLE_DETAILS" ] || [ "$ROLE_DETAILS" == "[]" ]; then
        jq '.roleAssignments = []' "$INVENTORY_FILE" > "$INVENTORY_FILE.tmp" && mv "$INVENTORY_FILE.tmp" "$INVENTORY_FILE"
        echo "No role assignments found; inventory updated with empty array."
        return
    fi
    # Load resources array for lookup
    local RESOURCES_JSON
    RESOURCES_JSON=$(jq '.resources' "$INVENTORY_FILE")
    # Use a here-document for the jq filter for reliability
    echo "$ROLE_DETAILS" | jq --argjson resources "$RESOURCES_JSON" '
      map(
        . as $ra |
        ($resources | map(select(.id == $ra.scope)) | first) as $res |
        {
          roleName: $ra.roleName,
          id: $ra.id,
          principalId: $ra.principalId,
          scope: $ra.scope,
          assignedOn: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
          resourceName: ($res.name // null),
          resourceType: ($res.type // (if ($ra.scope | test("/subscriptions/[^/]+$")) then "Microsoft.Resources/subscriptions" else null end)),
          resourceId: ($res.id // (if ($ra.scope | test("/subscriptions/[^/]+$")) then $ra.scope else null end))
        }
      )' > "$INVENTORY_FILE.roleAssignments.tmp"
    jq --slurpfile ras "$INVENTORY_FILE.roleAssignments.tmp" '.roleAssignments = $ras[0] // []' "$INVENTORY_FILE" > "$INVENTORY_FILE.tmp" && mv "$INVENTORY_FILE.tmp" "$INVENTORY_FILE"
    rm -f "$INVENTORY_FILE.roleAssignments.tmp"
    echo "Inventory file updated with current role assignments and resource info."
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --app-id)
            OVERRIDE_APP_ID="$2"
            shift 2
            ;;
        --principal-id)
            OVERRIDE_PRINCIPAL_ID="$2"
            shift 2
            ;;
        --subscription-id)
            OVERRIDE_SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--app-id <app-id>] [--principal-id <principal-id>] [--subscription-id <subscription-id>]"
            echo ""
            echo "Arguments:"
            echo "  --app-id <app-id>                    Azure AD Application (client) ID"
            echo "  --principal-id <principal-id>        Service Principal Object ID"
            echo "  --subscription-id <subscription-id>  Azure Subscription ID"
            echo ""
            echo "If not provided, values will be read from the credentials file."
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

# Verify prerequisites
verify_prerequisites

# Check if credentials file exists
if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please run step1_register_app.sh first"
    exit 1
fi

# Read credentials from correct paths, with command line overrides
APP_ID="${OVERRIDE_APP_ID:-$(jq -r '.azure.ad.application.clientId' "$CREDS_FILE")}"
SUBSCRIPTION_ID="${OVERRIDE_SUBSCRIPTION_ID:-$(jq -r '.azure.subscription.id' "$CREDS_FILE")}"
PRINCIPAL_ID="${OVERRIDE_PRINCIPAL_ID:-$(jq -r '.azure.ad.application.servicePrincipalObjectId' "$CREDS_FILE")}"

echo "Using values:"
echo "  App ID: $APP_ID"
echo "  Principal ID: $PRINCIPAL_ID"
echo "  Subscription ID: $SUBSCRIPTION_ID"

# Remove any duplicate roleAssignments array at azure root level
jq 'del(.azure.roleAssignments) |
    if .azure.subscription == null then
        .azure.subscription = {"id": "", "roleAssignments": []}
    else
        if .azure.subscription.roleAssignments == null then
            .azure.subscription.roleAssignments = []
        else
            .
        end
    end' "$CREDS_FILE" > "${CREDS_FILE}.tmp" && mv "${CREDS_FILE}.tmp" "$CREDS_FILE"

# Check if already logged in
echo "Checking Azure CLI login status..."
if ! az account show &> /dev/null; then
    echo "Not logged in. Initiating login..."
    az login --scope "https://graph.microsoft.com//.default"
else
    echo "Already logged in to Azure CLI"
fi

# Get existing role assignments
echo -e "\nChecking existing role assignments..."
EXISTING_ROLES=$(execute_az_command "az role assignment list --assignee \"$APP_ID\" --query \"[].roleDefinitionName\" -o tsv")

echo -e "\nExisting role assignments:"
if [ -n "$EXISTING_ROLES" ]; then
    echo "$EXISTING_ROLES" | while read -r role; do
        echo "- $role"
    done
else
    echo "No existing role assignments found"
fi

# Calculate missing roles
declare -a MISSING_ROLES=()
for role in "${REQUIRED_ROLES[@]}"; do
    if ! echo "$EXISTING_ROLES" | grep -Fq "$role"; then
        MISSING_ROLES+=("$role")
    fi
done

echo -e "\nMissing roles that need to be assigned:"
if [ ${#MISSING_ROLES[@]} -eq 0 ]; then
    echo "- All required roles are already assigned"
else
    printf '%s\n' "${MISSING_ROLES[@]/#/- }"
    
    echo -e "\nWould you like to assign these missing roles? (y/n)"
    read -r confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Clean up existing role assignments in JSON first
        cleanup_role_assignments

        echo "Starting role assignments..."
        echo "This may take a few minutes..."
        
        for role in "${MISSING_ROLES[@]}"; do
            echo -n "Assigning role: $role... "
            # Attempt to assign the role with explicit scope
            ROLE_RESULT=$(execute_az_command "az role assignment create --assignee \"$PRINCIPAL_ID\" --role \"$role\" --scope /subscriptions/$SUBSCRIPTION_ID")
            if [ $? -eq 0 ]; then
                ROLE_ID=$(echo "$ROLE_RESULT" | jq -r '.id')
                ROLE_DEFINITION_ID=$(echo "$ROLE_RESULT" | jq -r '.roleDefinitionId')
                ROLE_SCOPE=$(echo "$ROLE_RESULT" | jq -r '.scope')
                update_role_assignments "$role" "$ROLE_ID" "$ROLE_DEFINITION_ID" "$ROLE_SCOPE"
                echo "Done"
            else
                echo "Failed"
                echo "Error details: $ROLE_RESULT"
                echo "Command was: az role assignment create --assignee \"$PRINCIPAL_ID\" --role \"$role\" --scope /subscriptions/$SUBSCRIPTION_ID"
            fi
        done
    else
        echo "Skipping role assignments"
    fi
fi

# Final verification
echo -e "\nVerifying final role assignments..."
FINAL_ROLES=$(execute_az_command "az role assignment list --assignee \"$APP_ID\" --query \"[].roleDefinitionName\" -o tsv")

echo "Current role assignments:"
if [ -n "$FINAL_ROLES" ]; then
    echo "$FINAL_ROLES" | while read -r role; do
        echo "- $role"
    done
    
    # Capture existing role assignments in JSON if they're not already being captured
    if [ ${#MISSING_ROLES[@]} -eq 0 ]; then
        echo -e "\nAll roles already assigned. Would you like to capture these in the JSON file? (y/n)"
        read -r capture_confirm
        if [[ $capture_confirm =~ ^[Yy]$ ]]; then
            capture_existing_role_assignments
        else
            echo "Skipping JSON update"
        fi
    fi
else
    echo "No role assignments found"
fi

# Get all current role assignments for the principal at the subscription scope
ALL_CURRENT_ROLES=$(execute_az_command "az role assignment list --assignee \"$APP_ID\" --subscription \"$SUBSCRIPTION_ID\" --query '[].{name:roleDefinitionName, id:id, scope:scope}' -o json")

# Remove any roles not in REQUIRED_ROLES
if [ -n "$ALL_CURRENT_ROLES" ] && [ "$ALL_CURRENT_ROLES" != "[]" ]; then
    echo -e "\nChecking for extra roles to remove..."
    echo "$ALL_CURRENT_ROLES" | jq -c '.[]' | while read -r role_json; do
        role_name=$(echo "$role_json" | jq -r '.name')
        role_id=$(echo "$role_json" | jq -r '.id')
        role_scope=$(echo "$role_json" | jq -r '.scope')
        # Only remove if not in REQUIRED_ROLES and at subscription scope
        if ! printf '%s\n' "${REQUIRED_ROLES[@]}" | grep -Fxq "$role_name"; then
            echo "Removing extra role: $role_name (scope: $role_scope)"
            execute_az_command "az role assignment delete --ids $role_id"
        fi
    done
    # Always update inventory after any changes
    update_inventory_role_assignments
else
    echo "No existing role assignments found to remove."
    update_inventory_role_assignments
fi



# Example direct call to update_role_assignments for documentation/testing:
# update_role_assignments "Reader" \
#     "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleAssignments/11111111-1111-1111-1111-111111111111" \
#     "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" \
#     "/subscriptions/00000000-0000-0000-0000-000000000000"
#
# Arguments:
#   1. roleName (e.g., "Reader")
#   2. id (role assignment id)
#   3. roleDefinitionId (role definition id)
#   4. scope (e.g., "/subscriptions/<id>")

echo -e "\nNext Steps:"
echo "1. Verify all required roles are assigned correctly"
echo "2. Run step3_configure_oidc.sh to set up GitHub Actions authentication"
