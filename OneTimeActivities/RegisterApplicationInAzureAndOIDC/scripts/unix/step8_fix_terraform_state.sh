#!/usr/bin/env bash
# step8_fix_terraform_state.sh
# This script is a one-time utility to fix a common "state drift" issue where a
# resource (specifically a role assignment) exists in Azure but not in the
# Terraform state file. This typically happens after a failed pipeline run.
# run script if you  encounter a 409 RoleAssignmentExists error 
# This script will:
# 1. Navigate to the correct Terraform environment directory.
# 2. Find the Azure Resource ID of the pre-existing role assignment.
# 3. If it exists, it will initialize Terraform and import that resource into the state.
# 4. Run a 'terraform plan' to confirm the state is now clean.
#
# Preconditions:
# 1. You must run this script from the root of your Git repository.
# 2. You must have run the previous setup scripts (step1-step7).
# 3. You must be authenticated to Azure with permissions to read role assignments.
#
# Example Usage (from the root of the repository):
# bash ./OneTimeActivities/RegisterApplicationInAzureAndOIDC/scripts/unix/step8_fix_terraform_state.sh \
#   --tfstaterg rg-ag-pssg-tfstate-dev \
#   --tfstatesa stagpssgtfstatedev01 \
#   --tfstatecontainer sc-ag-pssg-tfstate-dev \
#   --apprg rg-ag-pssg-azure-poc-dev-att2 \
#   --appsa stagpssgazurepocdev01 \
#   --principalid <your-service-principal-object-id>

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
echo "Searching for existing 'Storage File Data SMB Share Contributor' role assignment..."
STORAGE_ACCOUNT_ID=$(az storage account show --name "$APP_SA" --resource-group "$APP_RG" --query id -o tsv)

if [[ -z "$STORAGE_ACCOUNT_ID" ]]; then
    echo "Warning: Application storage account '$APP_SA' not found. Cannot check for role assignment. Exiting."
    exit 0
fi

ROLE_ASSIGNMENT_ID=$(az role assignment list \
  --assignee "$PRINCIPAL_ID" \
  --scope "$STORAGE_ACCOUNT_ID" \
  --role "Storage File Data SMB Share Contributor" \
  --query "[0].id" -o tsv || true) # Use '|| true' to prevent script exit if role is not found

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
terraform import azurerm_role_assignment.storage_data_contributor_for_files "$ROLE_ASSIGNMENT_ID"

echo "✅ Import successful!"

# --- STEP 4: VERIFY THE STATE WITH A PLAN ---
echo "Running 'terraform plan' to verify that the state is clean..."
terraform plan -var-file=terraform.tfvars

echo "Terraform state has been successfully synchronized. You can now re-run your pipeline."