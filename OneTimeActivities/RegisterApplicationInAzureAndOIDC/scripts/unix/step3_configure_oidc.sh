#!/bin/bash

# Initialize variables
SCRIPT_DIR=""
PROJECT_ROOT=""
ENV_DIR=""
CREDS_FILE=""
APP_ID=""
GITHUB_ORG="bcgov"
GITHUB_REPO="AzureFilesPoC"
ENVIRONMENTS=("dev")  # Add "test", "prod" when needed

# Function to resolve script location and set correct paths
resolve_script_path() {
    local script_path
    # Get the real path of the script, resolving any symlinks
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    # Extract the directory
    SCRIPT_DIR="$(dirname "$script_path")"
    
    # Navigate to project root (up from scripts/unix/RegisterApplicationInAzureAndOIDC/OneTimeActivities)
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
    ENV_DIR="$PROJECT_ROOT/.env"
    CREDS_FILE="$ENV_DIR/azure-credentials.json"
    
    echo "Script running from: $SCRIPT_DIR"
    echo "Project root: $PROJECT_ROOT"
}

# Call path resolution function
resolve_script_path

# Function to check if already logged in
check_login_status() {
    echo "Checking Azure CLI login status..."
    local login_check
    login_check=$(az account show 2>&1)
    if [ $? -eq 0 ]; then
        echo "Already logged in to Azure CLI"
        return 0
    else
        echo "Not logged in to Azure CLI"
        return 1
    fi
}

# Function to ensure logged in with correct permissions
ensure_logged_in() {
    if ! check_login_status; then
        echo "Please log in to Azure CLI first using 'az login'"
        exit 1
    fi

    # Check subscription selection
    current_sub=$(execute_az_command "az account show --query name -o tsv")
    if [ $? -ne 0 ]; then
        echo "Failed to get current subscription"
        exit 1
    fi

    # Get subscription from credentials file
    local sub_name
    sub_name=$(jq -r '.azure.subscriptionName // empty' "$CREDS_FILE")
    if [ -n "$sub_name" ] && [ "$current_sub" != "$sub_name" ]; then
        echo "Warning: Current subscription ($current_sub) does not match configuration ($sub_name)"
        echo "Available subscriptions:"
        execute_az_command "az account list --query '[].{name:name, id:id}' -o table"
        echo -e "\nPlease select the correct subscription using: az account set --subscription \"<name or id>\""
        echo "Press Enter to continue with current subscription, or Ctrl+C to exit"
        read -r
    fi

    # Verify Graph API permissions quietly - only show messages if refresh needed
    local token_check
    token_check=$(az account get-access-token --resource-type ms-graph 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Refreshing Microsoft Graph permissions..."
        az login --scope "https://graph.microsoft.com//.default"
        if [ $? -ne 0 ]; then
            echo "Failed to get required Microsoft Graph permissions. Please try again."
            exit 1
        fi
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

# Function to update credentials file
update_credentials_file() {
    local credential_name=$1
    local subject=$2
    
    # Read current file
    local json_content
    json_content=$(cat "$CREDS_FILE")
    
    # Get current timestamp (ISO 8601)
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    # Create new credential entry
    local new_credential
    new_credential=$(cat << EOF
{
  "name": "$credential_name",
  "subject": "$subject",
  "issuer": "https://token.actions.githubusercontent.com",
  "audiences": ["api://AzureADTokenExchange"],
  "configuredOn": "$timestamp"
}
EOF
)
    
    # Update JSON file using jq - remove existing credential with same name first
    echo "$json_content" | jq \
        --arg cred "$new_credential" \
        --arg name "$credential_name" \
        --arg time "$timestamp" \
        '
        # Ensure nested structure exists
        if .azure.ad.application.oidcConfiguration == null then
            .azure.ad.application.oidcConfiguration = {
                "federatedCredentials": [],
                "configuredOn": ""
            }
        end |
        # Remove existing credential with same name
        .azure.ad.application.oidcConfiguration.federatedCredentials = [
            .azure.ad.application.oidcConfiguration.federatedCredentials[]
            | select(.name != $name)
        ] |
        # Add new credential
        .azure.ad.application.oidcConfiguration.federatedCredentials += [($cred | fromjson)] |
        # Update timestamp
        .azure.ad.application.oidcConfiguration.configuredOn = $time |
        # Update lastUpdated metadata
        .metadata.lastUpdated = $time
        ' > "${CREDS_FILE}.tmp" && mv "${CREDS_FILE}.tmp" "$CREDS_FILE"
    
    echo "Updated credentials file with federated credential: $credential_name"
}

# Function to create federated credential
create_federated_credential() {
    local name=$1
    local subject=$2
    local app_id=$3
    
    echo "Checking for existing federated credential: $name"
    local existing
    existing=$(execute_az_command "az ad app federated-credential list --id \"$app_id\" --query \"[?name=='$name'].name\" -o tsv")
    
    if [ -n "$existing" ] && [ "$existing" != "null" ]; then
        echo "Federated credential '$name' already exists"
        # Update JSON even if credential exists to ensure consistency
        update_credentials_file "$name" "$subject"
        return 0
    fi
    
    echo "Creating federated credential: $name"
    local credential
    read -r -d '' credential << EOM
{
    "name": "$name",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "$subject",
    "audiences": ["api://AzureADTokenExchange"]
}
EOM
    
    # Create temporary file for the credential JSON
    local temp_file
    temp_file=$(mktemp)
    echo "$credential" > "$temp_file"
    
    # Create the federated credential
    local result
    result=$(execute_az_command "az ad app federated-credential create --id \"$app_id\" --parameters @\"$temp_file\"")
    
    # Clean up temporary file
    rm "$temp_file"
    
    if [ -n "$result" ]; then
        # Update JSON file with the new credential
        update_credentials_file "$name" "$subject"
        echo "$result"
        return 0
    fi
    return 1
}

# Function to sync federated credentials from Azure to the credentials file
sync_federated_credentials_from_azure() {
    local app_id=$1
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local creds_json
    creds_json=$(az ad app federated-credential list --id "$app_id" 2>/dev/null)
    if [ -n "$creds_json" ]; then
        jq --argjson creds "$creds_json" --arg time "$timestamp" '
            .azure.ad.application.oidcConfiguration.federatedCredentials = $creds |
            .azure.ad.application.oidcConfiguration.configuredOn = $time |
            .metadata.lastUpdated = $time
        ' "$CREDS_FILE" > "${CREDS_FILE}.tmp" && mv "${CREDS_FILE}.tmp" "$CREDS_FILE"
        echo "Synchronized federatedCredentials from Azure."
    else
        echo "Warning: No federated credentials found in Azure or failed to fetch."
    fi
}

# Verify credentials file exists
if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please run step1_register_app.sh first"
    exit 1
fi

# Ensure logged in with correct permissions before proceeding
ensure_logged_in

# Read credentials from file
echo "Reading credentials from $CREDS_FILE..."
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install using: brew install jq"
    exit 1
fi

# Read variables from JSON with new paths
APP_ID=$(jq -r '.azure.ad.application.clientId' "$CREDS_FILE")
GITHUB_ORG=$(jq -r '.github.org // empty' "$CREDS_FILE")
GITHUB_REPO=$(jq -r '.github.repo // empty' "$CREDS_FILE")

if [ -z "$APP_ID" ] || [ "$APP_ID" = "null" ]; then
    echo "Error: Could not read app ID from credentials file"
    exit 1
fi

# Use default values if not found in JSON
if [ -z "$GITHUB_ORG" ] || [ "$GITHUB_ORG" = "null" ]; then
    GITHUB_ORG="bcgov"
fi

if [ -z "$GITHUB_REPO" ] || [ "$GITHUB_REPO" = "null" ]; then
    GITHUB_REPO="AzureFilesPoC"
fi

# Function to check subscription
check_subscription() {
    echo "Current Azure subscription:"
    local current_sub
    current_sub=$(execute_az_command "az account show --query name -o tsv")
    if [ $? -ne 0 ]; then
        echo "Failed to get current subscription"
        return 1
    fi

    # Verify the subscription
    local sub_name
    sub_name=$(jq -r '.azure.subscriptionName // empty' "$CREDS_FILE")
    if [ -n "$sub_name" ] && [ "$current_sub" != "$sub_name" ]; then
        echo "Warning: Current subscription ($current_sub) does not match configuration ($sub_name)"
        echo "Available subscriptions:"
        execute_az_command "az account list --query '[].{name:name, id:id}' -o table"
        echo -e "\nPlease select the correct subscription using: az account set --subscription \"<name or id>\""
        echo "Press Enter to continue with current subscription, or Ctrl+C to exit"
        read -r
    fi
    return 0
}

# Check subscription configuration
check_subscription || exit 1

# Configure federated credentials
echo -e "\nConfiguring federated credentials for GitHub Actions..."

# Main branch credential
create_federated_credential \
    "github-federated-identity-main-branch" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main" \
    "$APP_ID"

# Pull request credential
create_federated_credential \
    "github-federated-identity-pull-requests" \
    "repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request" \
    "$APP_ID"

# Environment credentials
for env in "${ENVIRONMENTS[@]}"; do
    create_federated_credential \
        "github-federated-identity-${env}-environment" \
        "repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${env}" \
        "$APP_ID"
done

# After all federated credentials are created/updated, sync from Azure
sync_federated_credentials_from_azure "$APP_ID"

# Final verification
echo -e "\nVerifying federated credentials..."
execute_az_command "az ad app federated-credential list --id \"$APP_ID\" --query '[].{Name:name, Subject:subject}' -o table"

echo -e "\nFederated credentials setup complete. Please verify the configuration in Azure Portal:"
echo "1. Go to Microsoft Entra ID > App registrations"
echo "2. Find your app registration"
echo "3. Check Certificates & secrets > Federated credentials"
