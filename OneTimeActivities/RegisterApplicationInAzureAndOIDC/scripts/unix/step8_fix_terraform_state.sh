#!/usr/bin/env bash
# step8_fix_terraform_state.sh
# -----------------------------------------------------------------------------
# SUMMARY:
#   This is a utility/troubleshooting script for fixing Terraform state drift issues.
#   It resolves conflicts when Azure resources exist but are missing from Terraform state,
#   typically after a failed pipeline run or partial deployment.
#
# WHEN TO USE THIS SCRIPT:
#   - You encounter a "409 RoleAssignmentExists" error during Terraform deployment
#   - GitHub Actions pipeline fails with "resource already exists" errors
#   - Terraform thinks a resource doesn't exist, but Azure shows it does
#   - You need to recover from a failed/interrupted pipeline run
#
# WHAT IT DOES:
#   1. Searches for existing role assignments in Azure that conflict with Terraform
#   2. Imports those existing resources into the Terraform state file
#   3. Synchronizes the state so Terraform recognizes the existing resources
#   4. Verifies the fix with 'terraform plan' to ensure no conflicts remain
#
# TYPICAL ERROR SYMPTOMS:
#   Error: A resource with the ID "/subscriptions/.../roleAssignments/..." already exists
#   StatusCode: 409
#   RoleAssignmentExists: The role assignment already exists.
#
# USAGE:
#   bash step8_fix_terraform_state.sh \
#     --tfstaterg "rg-<project-name>-tfstate-dev" \
#     --tfstatesa "st<projectname>tfstatedev01" \
#     --tfstatecontainer "sc-<project-name>-tfstate-dev" \
#     --apprg "rg-<project-name>-dev" \
#     --appsa "st<projectname>dev01" \
#     --principalid "<your-service-principal-object-id>"
#
# PREREQUISITES:
#   - Must be run from the root of your Git repository
#   - Steps 1-7 of the onboarding process must be completed
#   - Azure CLI authenticated with permissions to read role assignments
#   - Terraform installed and accessible in PATH
#
# IMPLEMENTATION NOTES:
#   - This is NOT part of normal onboarding (steps 1-7 are sufficient for most setups)
#   - Only run this if you encounter Terraform state conflicts
#   - Script is idempotent - safe to run multiple times
#   - Focuses specifically on "Network Contributor" role assignment conflicts
#   - Uses terraform import to synchronize existing Azure resources with state
#
# NEXT STEPS AFTER RUNNING:
#   1. Verify 'terraform plan' shows no changes needed
#   2. Re-run your failed GitHub Actions pipeline
#   3. Monitor subsequent deployments for similar issues
# -----------------------------------------------------------------------------

set -euo pipefail

# --- ARGUMENT PARSING ---
TF_STATE_RG=""
TF_STATE_SA=""
TF_STATE_CONTAINER=""
APP_RG=""
APP_SA=""
PRINCIPAL_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tfstaterg)
      TF_STATE_RG="$2"; shift 2;;
    --tfstatesa)
      TF_STATE_SA="$2"; shift 2;;
    --tfstatecontainer)
      TF_STATE_CONTAINER="$2"; shift 2;;
    --apprg)
      APP_RG="$2"; shift 2;;
    --appsa)
      APP_SA="$2"; shift 2;;
    --principalid)
      PRINCIPAL_ID="$2"; shift 2;;
    -h|--help)
      echo "Usage: $0 --tfstaterg <tf-rg> --tfstatesa <tf-sa> --tfstatecontainer <tf-container> --apprg <app-rg> --appsa <app-sa> --principalid <sp-id>"
      exit 0;;
    *)
      echo "Unknown argument: $1"; exit 1;;
  esac
done

if [[ -z "$TF_STATE_RG" || -z "$TF_STATE_SA" || -z "$TF_STATE_CONTAINER" || -z "$APP_RG" || -z "$APP_SA" || -z "$PRINCIPAL_ID" ]]; then
  echo "Error: All arguments are required."
  exit 1
fi

# --- NAVIGATE TO THE TERRAFORM ENVIRONMENT DIRECTORY ---
# This script assumes it's being run from the repository root.
TERRAFORM_DIR="./terraform/environments/dev"
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "Error: Directory '$TERRAFORM_DIR' not found. Please run this script from the root of your repository."
    exit 1
fi
cd "$TERRAFORM_DIR"
echo "Changed directory to $(pwd)"

# --- STEP 1: FIND THE EXISTING ROLE ASSIGNMENT ID ---
echo "Searching for existing 'Network Contributor' role assignment on the resource group..."

# Get the resource group ID for the assignment scope
RESOURCE_GROUP_ID=$(az group show --name "$APP_RG" --query id -o tsv)

if [[ -z "$RESOURCE_GROUP_ID" ]]; then
    echo "Warning: Resource group '$APP_RG' not found. Cannot check for role assignment. Exiting."
    exit 0
fi

ROLE_ASSIGNMENT_ID=$(az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --scope "$RESOURCE_GROUP_ID" \
  --role "Network Contributor" \
  --query "[0].id" -o tsv || true)

if [[ -z "$ROLE_ASSIGNMENT_ID" ]]; then
  echo "✅ No pre-existing role assignment found. No import needed."
  exit 0
fi

echo "Found existing role assignment with ID: $ROLE_ASSIGNMENT_ID"

# --- STEP 2: INITIALIZE TERRAFORM TO CONNECT TO THE REMOTE BACKEND ---
echo "Initializing Terraform..."
terraform init \
  -backend-config="resource_group_name=$TF_STATE_RG" \
  -backend-config="storage_account_name=$TF_STATE_SA" \
  -backend-config="container_name=$TF_STATE_CONTAINER" \
  -backend-config="key=dev.terraform.tfstate"

# --- STEP 3: IMPORT THE EXISTING RESOURCE INTO TERRAFORM STATE ---
echo "Importing the role assignment into Terraform state..."
terraform import azurerm_role_assignment.github_actions_network_contributor "$ROLE_ASSIGNMENT_ID"

echo "✅ Import successful!"

# --- STEP 4: VERIFY THE STATE WITH A PLAN ---
echo "Running 'terraform plan' to verify that the state is clean..."
terraform plan -var-file=terraform.tfvars

echo "Terraform state has been successfully synchronized. You can now re-run your pipeline."