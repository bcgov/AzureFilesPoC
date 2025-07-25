#!/bin/bash
# step5_add_github_secrets_cli.sh
# -----------------------------------------------------------------------------
# SUMMARY:
#   This script automates the process of adding Azure credentials as GitHub repository secrets
#   using the GitHub CLI (`gh`). It is an alternative to manual entry and is intended for onboarding
#   automation and repeatable CI/CD setup.
#
#   The secrets added are:
#     - AZURE_CLIENT_ID
#     - AZURE_TENANT_ID
#     - AZURE_SUBSCRIPTION_ID
#
#   These are required for GitHub Actions workflows to authenticate to Azure using federated OIDC credentials.
#
# USAGE:
#   bash step5_add_github_secrets_cli.sh
#
# PREREQUISITES:
#   - GitHub CLI (`gh`) installed and authenticated (run `gh auth login` if needed)
#   - jq installed for JSON processing
#   - azure-credentials.json file created by step1_register_app.sh
#   - Sufficient permissions to add secrets to the target GitHub repository
#
# IMPLEMENTATION NOTES:
#   - Idempotent: running this script multiple times will not create duplicate secrets; existing ones are updated in-place.
#   - All CLI and jq commands are checked for prerequisites and errors.
#   - The script never stores actual secret values in the repository; only in the local .env/azure-credentials.json for reference.
#   - For troubleshooting, check the output and the state of the credentials file after running.
#   - If you add new secrets or change the onboarding flow, update both the script and the documentation above.
#
# NEXT STEPS:
#   1. Verify the secrets in GitHub by visiting the repository settings.
#   2. Mark this step as complete in the onboarding checklist or README.md.
#   3. Continue with the next onboarding script as per your workflow.
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

# Function to check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Function to verify prerequisites
verify_prerequisites() {
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI is required but not installed."
        if is_macos; then
            echo "Install using: brew install gh"
        else
            echo "Install using your package manager or visit: https://cli.github.com/manual/installation"
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
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        echo "GitHub CLI is not authenticated. Please login first."
        echo "Run: gh auth login"
        exit 1
    fi
}

# Verify prerequisites
verify_prerequisites

# Check if credentials file exists
CREDS_FILE="$PROJECT_ROOT/.env/azure-credentials.json"

if [ ! -f "$CREDS_FILE" ]; then
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please run step1_register_app.sh first"
    exit 1
fi

# Read credentials using new JSON structure only
CLIENT_ID=$(jq -r '.azure.ad.application.clientId' "$CREDS_FILE")
TENANT_ID=$(jq -r '.azure.ad.tenantId' "$CREDS_FILE")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id' "$CREDS_FILE")
GITHUB_ORG=$(jq -r '.github.org' "$CREDS_FILE")
GITHUB_REPO=$(jq -r '.github.repo' "$CREDS_FILE")

# Validate the required values
if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
    echo "Error: Client ID not found in credentials file"
    exit 1
fi

if [[ -z "$TENANT_ID" || "$TENANT_ID" == "null" ]]; then
    echo "Error: Tenant ID not found in credentials file"
    exit 1
fi

if [[ -z "$SUBSCRIPTION_ID" || "$SUBSCRIPTION_ID" == "null" ]]; then
    echo "Error: Subscription ID not found in credentials file"
    exit 1
fi

if [[ -z "$GITHUB_ORG" || "$GITHUB_ORG" == "null" || -z "$GITHUB_REPO" || "$GITHUB_REPO" == "null" ]]; then
    GITHUB_ORG="bcgov"
    GITHUB_REPO="AzureFilesPoC"
    echo "GitHub organization or repo not found in credentials file, using defaults:"
    echo "Organization: $GITHUB_ORG"
    echo "Repository: $GITHUB_REPO"
fi

REPO_PATH="$GITHUB_ORG/$GITHUB_REPO"

echo "========== Adding GitHub Repository Secrets =========="
echo "Using GitHub CLI to add secrets to repository: $REPO_PATH"

echo "Values being set as GitHub secrets (for verification):"
echo "AZURE_CLIENT_ID: $CLIENT_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""

# Create each secret with the GitHub CLI
echo "Adding AZURE_CLIENT_ID secret..."
if gh secret set AZURE_CLIENT_ID --body "$CLIENT_ID" --repo "$REPO_PATH"; then
    echo "✅ Successfully added AZURE_CLIENT_ID secret"
else
    echo "❌ Failed to add AZURE_CLIENT_ID secret"
    echo "Please check your GitHub CLI authentication and repository access permissions"
    exit 1
fi

echo "Adding AZURE_TENANT_ID secret..."
if gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$REPO_PATH"; then
    echo "✅ Successfully added AZURE_TENANT_ID secret"
else
    echo "❌ Failed to add AZURE_TENANT_ID secret"
    exit 1
fi

echo "Adding AZURE_SUBSCRIPTION_ID secret..."
if gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$REPO_PATH"; then
    echo "✅ Successfully added AZURE_SUBSCRIPTION_ID secret"
else
    echo "❌ Failed to add AZURE_SUBSCRIPTION_ID secret"
    exit 1
fi

echo ""
echo "🎉 All GitHub secrets have been successfully added!"
echo ""

# Update secrets configuration in JSON file
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
TEMP_FILE=$(mktemp)

# Only update/merge the relevant fields in .github.secrets
jq --arg timestamp "$TIMESTAMP" '
  .github.secrets.available = (["AZURE_CLIENT_ID", "AZURE_TENANT_ID", "AZURE_SUBSCRIPTION_ID"]) |
  .github.secrets.secretsAddedCLI = true |
  .github.secrets.secretsAddedCLIOn = $timestamp
' "$CREDS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CREDS_FILE"

echo "✅ Secret status updated in credentials file"
echo ""
echo "Next Steps:"
echo "1. Verify the secrets in GitHub by visiting:"
echo "   https://github.com/$REPO_PATH/settings/secrets/actions"
echo "2. Update the Progress Tracking table in README.md to mark Step 5 as complete"
echo "3. Proceed to Step 6: Validate Your Setup by following the validation process"
echo ""
