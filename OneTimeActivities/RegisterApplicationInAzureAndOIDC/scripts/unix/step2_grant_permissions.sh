#!/bin/bash

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

# Required roles
REQUIRED_ROLES=(
    # Base roles
    "Reader"
    "Storage Account Contributor"
    "[BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor"
    "Private DNS Zone Contributor"
    "Monitoring Contributor"
    
    # Storage-specific roles
    "Storage Account Backup Contributor"
    "Storage Blob Data Owner"
    "Storage File Data Privileged Contributor"
    "Storage File Data SMB Share Elevated Contributor"
    "Storage Blob Delegator"
    "Storage File Delegator"
    
    # Additional data plane roles
    "Storage Queue Data Contributor"
    "Storage Table Data Contributor"
    "DNS Resolver Contributor"
    "Azure Container Storage Contributor"
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
    # Add the new role assignment under azure.subscription.roleAssignments
    jq --arg principal_id "$PRINCIPAL_ID" \
       --arg role_definition_id "$role_definition_id" \
       --arg scope "$scope" \
       --arg assigned_on "$assigned_on" \
       '
       .azure.subscription.roleAssignments += [{
           "principalId": $principal_id,
           "roleDefinitionId": $role_definition_id,
           "scope": $scope,
           "assignedOn": $assigned_on
       }]
       ' "$CREDS_FILE" > "$temp_file"
    mv "$temp_file" "$CREDS_FILE"
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
    
    # Process each role assignment and add to JSON
    echo "$ROLE_DETAILS" | jq -c '.[]' | while read -r role_json; do
        local role_name
        local role_id
        local principal_id
        local scope
        
        role_name=$(echo "$role_json" | jq -r '.roleName')
        role_id=$(echo "$role_json" | jq -r '.id')
        principal_id=$(echo "$role_json" | jq -r '.principalId')
        scope=$(echo "$role_json" | jq -r '.scope')
        
        echo "Capturing existing role: $role_name"
        
        # Add to JSON file
        local temp_file
        temp_file=$(mktemp)
        
        jq --arg name "$role_name" \
           --arg id "$role_id" \
           --arg date "$(date '+%Y-%m-%d %H:%M:%S')" \
           --arg scope "$scope" \
           --arg principal_id "$principal_id" \
           '
           .azure.subscription.roleAssignments += [{
               "roleName": $name,
               "id": $id,
               "principalId": $principal_id,
               "scope": $scope,
               "assignedOn": $date
           }]
           ' "$CREDS_FILE" > "$temp_file"
        
        # Replace original file with updated content
        mv "$temp_file" "$CREDS_FILE"
    done
    
    echo "All existing role assignments captured in credentials file"
}

# Verify prerequisites
verify_prerequisites

# Check if credentials file exists
if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please run step1_register_app.sh first"
    exit 1
fi

# Read credentials from correct paths
APP_ID=$(jq -r '.azure.ad.application.clientId' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id' "$CREDS_FILE")
PRINCIPAL_ID=$(jq -r '.azure.ad.application.servicePrincipalObjectId' "$CREDS_FILE")

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
            
            # Attempt to assign the role
            ROLE_RESULT=$(execute_az_command "az role assignment create --assignee \"$APP_ID\" --role \"$role\" --subscription \"$SUBSCRIPTION_ID\"")
            if [ $? -eq 0 ]; then
                ROLE_ID=$(echo "$ROLE_RESULT" | jq -r '.id')
                update_role_assignments "$role" "$ROLE_ID"
                echo "Done"
            else
                echo "Failed"
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

echo -e "\nNext Steps:"
echo "1. Verify all required roles are assigned correctly"
echo "2. Run step3_configure_oidc.sh to set up GitHub Actions authentication"
