#!/bin/bash
# ================================================================
# step1_register_app.sh
#
# SUMMARY:
#   This script registers an Azure AD application and service principal for use with automation and GitHub Actions OIDC authentication.
#   It ensures you are logged in with the correct Microsoft Graph permissions, creates or reuses the app registration, and updates local credentials.
#
# WHAT IT DOES:
#   - Verifies Azure CLI and jq are installed.
#   - Ensures you are logged in to Azure CLI with Microsoft Graph permissions.
#   - Prompts for subscription selection.
#   - Creates or reuses an Azure AD application registration.
#   - Creates or reuses a service principal for the app.
#   - Updates a local credentials JSON file with all relevant IDs.
#
# USAGE:
#   bash step1_register_app.sh
#
# PRECONDITIONS:
#   - Azure CLI and jq are installed.
#   - You have Microsoft Graph API permissions (see login instructions below).
#   - You have access to the target Azure subscription.
#
# INPUTS:
#   - Interactive: prompts for subscription selection if not set.
#
# OUTPUTS:
#   - Updates .env/azure-credentials.json with app, SP, tenant, and subscription IDs.
#   - Prints registration results and next steps.
#
# TROUBLESHOOTING:
#   - If you see authentication errors, ensure you are logged in with the correct scope:
#       az login --scope https://graph.microsoft.com/.default
#   - If you have multiple subscriptions, set the correct one:
#       az account set --subscription "<your-subscription-id>"
#
# NEXT STEPS:
#   1. Run step2_grant_permissions.sh to assign required roles.
#   2. Run step3_configure_oidc.sh to set up GitHub Actions authentication.
# ================================================================

# Manual Azure Login Required
# ------------------------------------------------------------
# Before running this script, you must be logged in to Azure CLI
# with Microsoft Graph permissions. Run the following command:
#
#   az login --scope https://graph.microsoft.com/.default
#
# This will open a browser window for you to authenticate.
# If you have multiple subscriptions, set the correct one:
#   az account set --subscription "<your-subscription-id>"
#
# ------------------------------------------------------------

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
APP_NAME="<project-name>-ServicePrincipal"
ENV_DIR="$PROJECT_ROOT/.env"
CREDS_FILE="$ENV_DIR/azure-credentials.json"
TEMPLATE_FILE="$ENV_DIR/azure-credentials.template.json"
GITHUB_ORG="<github-org>"
GITHUB_REPO="<github-repo>"

# Function to initialize credentials file from template
initialize_credentials_file() {
    # Create .env directory if it doesn't exist
    mkdir -p "$ENV_DIR"

    # Check if template exists
    if [ ! -f "$TEMPLATE_FILE" ]; then
        echo "Error: Template file not found at $TEMPLATE_FILE"
        exit 1
    fi

    # Copy template to credentials file if it doesn't exist
    if [ ! -f "$CREDS_FILE" ]; then
        echo "Initializing credentials file from template..."
        cp "$TEMPLATE_FILE" "$CREDS_FILE"
        
        # Update GitHub values and ensure clean structure
        jq --arg org "$GITHUB_ORG" --arg repo "$GITHUB_REPO" '
           .github.org = $org | 
           .github.repo = $repo | 
           .azure.subscription.roleAssignments = []
           ' "$CREDS_FILE" > "$CREDS_FILE.tmp" && mv "$CREDS_FILE.tmp" "$CREDS_FILE"
    fi

    # Verify the file is valid JSON
    if ! jq '.' "$CREDS_FILE" > /dev/null 2>&1; then
        echo "Error: Invalid JSON in credentials file"
        exit 1
    fi
}

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

# Function to check if already logged in
check_login_status() {
    az account show &> /dev/null
}

# Function to ensure logged in with correct permissions
ensure_logged_in() {
    if ! check_login_status; then
        echo "Not logged in to Azure CLI. Launching browser for login..."
        az login --scope "https://graph.microsoft.com/.default"
        if [ $? -ne 0 ]; then
            echo "Login failed. Please try again."
            exit 1
        fi
    fi
    # Verify Graph API permissions
    echo "Verifying Microsoft Graph API permissions..."
    az account get-access-token --resource-type ms-graph &> /dev/null
    if [ $? -ne 0 ]; then
        echo "Refreshing login with Microsoft Graph permissions..."
        az login --scope "https://graph.microsoft.com/.default"
        if [ $? -ne 0 ]; then
            echo "Failed to get required Microsoft Graph permissions. Please try again."
            exit 1
        fi
    fi
    # Display current context
    echo "Current Azure context:"
    az account show -o table
    echo -e "\nPress Enter to continue with this context, or Ctrl+C to exit and run 'az login' with different credentials"
    read -r
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
            if [[ $result =~ "AADSTS70043" ]] || [[ $result =~ "expired" ]]; then
                echo "Token expired or permission issue detected. Attempting to refresh login..."
                az account clear
                az login --scope "https://graph.microsoft.com/.default"
                retry=$((retry + 1))
                echo "Retrying command... (Attempt $retry of $max_retries)"
                continue
            elif [[ $result =~ "authentication needed" ]]; then
                echo "Authentication needed. Please login again..."
                az login --scope "https://graph.microsoft.com/.default"
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
update_credentials() {
    local field=$1
    local value=$2
    local jq_filter
    mkdir -p "$ENV_DIR"
    if [ ! -f "$CREDS_FILE" ]; then
        initialize_credentials_file
    fi
    case $field in
        "metadata.dateCreated")
            jq_filter=".metadata.dateCreated = \"$value\""
            ;;
        "metadata.lastUpdated")
            jq_filter=".metadata.lastUpdated = \"$value\""
            ;;
        "azure.ad.tenantId")
            jq_filter=".azure.ad.tenantId = \"$value\""
            ;;
        "azure.subscription.id")
            jq_filter=".azure.subscription.id = \"$value\""
            ;;
        "azure.ad.application.name")
            jq_filter=".azure.ad.application.name = \"$value\""
            ;;
        "azure.ad.application.clientId")
            jq_filter=".azure.ad.application.clientId = \"$value\""
            ;;
        "azure.ad.application.objectId")
            jq_filter=".azure.ad.application.objectId = \"$value\""
            ;;
    esac
    local temp_file=$(mktemp)
    jq "$jq_filter" "$CREDS_FILE" > "$temp_file" && mv "$temp_file" "$CREDS_FILE"
    echo "Updated $field in credentials file"
}

# Verify prerequisites
verify_prerequisites

# Ensure logged in with correct permissions before proceeding
ensure_logged_in

# Initialize credentials file from template
initialize_credentials_file

# List available subscriptions and prompt for selection
echo -e "\nAvailable subscriptions:"
az account list --output table

echo -e "\nPlease select a subscription by copying its ID and pressing Enter"
echo -e "(or press Enter to use the default subscription):"
read -r subscription_input

if [ -n "$subscription_input" ]; then
    echo "Setting subscription to: $subscription_input"
    az account set --subscription "$subscription_input"
fi

# Verify selected subscription
echo -e "\nUsing subscription:"
az account show --output table

# Get or create app registration
echo "Checking for existing app registration..."
EXISTING_APP=$(execute_az_command "az ad app list --display-name \"$APP_NAME\" --query '[0].appId' -o tsv")

if [ -n "$EXISTING_APP" ] && [ "$EXISTING_APP" != "null" ]; then
    echo "Found existing app registration with ID: $EXISTING_APP"
    APP_ID=$EXISTING_APP
else
    echo "Creating new app registration..."
    APP_ID=$(execute_az_command "az ad app create --display-name \"$APP_NAME\" --query 'appId' -o tsv")
    echo "Created new app registration with ID: $APP_ID"
fi

# Get or create service principal
echo "Checking for existing service principal..."
EXISTING_SP=$(execute_az_command "az ad sp list --display-name \"$APP_NAME\" --query '[0].id' -o tsv")

if [ -n "$EXISTING_SP" ] && [ "$EXISTING_SP" != "null" ]; then
    echo "Found existing service principal"
    SP_ID=$EXISTING_SP
else
    echo "Creating service principal..."
    execute_az_command "az ad sp create --id \"$APP_ID\""
    SP_ID=$(execute_az_command "az ad sp list --display-name \"$APP_NAME\" --query '[0].id' -o tsv")
    echo "Created service principal"
fi

# Update credentials with tenant and subscription info
TENANT_ID=$(az account show --query 'tenantId' -o tsv)
SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)

echo "Updating credentials with initial Azure account information..."
update_credentials "metadata.dateCreated" "$(date '+%Y-%m-%d %H:%M')"
update_credentials "azure.ad.tenantId" "$TENANT_ID"
update_credentials "azure.subscription.id" "$SUBSCRIPTION_ID"

# Update application information
update_credentials "azure.ad.application.name" "$APP_NAME"
update_credentials "azure.ad.application.clientId" "$APP_ID"
update_credentials "azure.ad.application.objectId" "$SP_ID"

echo "Credentials file has been updated with all registration details"

# Display results
echo -e "\nRegistration Results:"
echo "- Client ID: $APP_ID"
echo "- Tenant ID: $TENANT_ID"
echo "- Subscription ID: $SUBSCRIPTION_ID"
echo "- Service Principal Object ID: $SP_ID"

echo -e "\nNext Steps:"
echo "1. Verify these values match your existing app registration"
echo "2. Run step2_grant_permissions.sh to verify/set up role assignments"
echo "3. Run step3_configure_oidc.sh to set up GitHub Actions authentication"
if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Failed to create credentials file"
    exit 1
fi

if ! jq '.' "$CREDS_FILE" > /dev/null 2>&1; then
    echo "Error: Generated invalid JSON"
    exit 1
fi

echo "Credentials saved to $CREDS_FILE"

# Display the saved credentials
echo "Saved credentials:"
jq '.' "$CREDS_FILE"

# Display results
echo -e "\nRegistration Results:"
echo "- Client ID: $APP_ID"
echo "- Tenant ID: $TENANT_ID"
echo "- Subscription ID: $SUBSCRIPTION_ID"
echo "- Service Principal Object ID: $SP_ID"

echo -e "\nNext Steps:"
echo "1. Verify these values match your existing app registration"
echo "2. Run step2_grant_permissions.sh to verify/set up role assignments"
echo "3. Run step3_configure_oidc.sh to set up GitHub Actions authentication"
