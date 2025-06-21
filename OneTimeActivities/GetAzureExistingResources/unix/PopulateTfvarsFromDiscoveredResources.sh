#!/usr/bin/env bash
# PopulateTfvarsFromDiscoveredResources.sh
# Reads .env/azure_full_inventory.json to populate terraform.tfvars and secrets.tfvars
# Usage: ./PopulateTfvarsFromDiscoveredResources.sh

#PREREQUISITES
# - Ensure you have run RegisterApplicationInAzureAndOIDC.sh to set up Azure credentials
# - Ensure you have the Azure CLI installed and configured
# - Ensure you have jq installed for JSON processing
# - Ensure you have the Azure CLI logged in to the correct subscription
# - Ensure you have the Azure CLI configured to allow dynamic extension installation
# - ensure you have run the following script:
#   - OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh

##KEY INPUTS
# - Values in the following JSON files: 
#  - .env/azure-credentials.json
#  - .env/azure_full_inventory.json
# - Templates in terraform/terraform.tfvars.template and terraform/secrets.tfvars.template
# - Output files: terraform/terraform.tfvars and terraform/secrets.tfvars

set -e

# Function to resolve script location and set correct paths
resolve_script_path() {
    local script_path
    script_path="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)/$(basename "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(dirname "$script_path")"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
}

resolve_script_path

ENV_DIR="$PROJECT_ROOT/.env"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

INVENTORY_JSON="$ENV_DIR/azure_full_inventory.json"
CREDENTIALS_JSON="$ENV_DIR/azure-credentials.json"
TFVARS_TEMPLATE="$TERRAFORM_DIR/terraform.tfvars.template"
SECRETS_TEMPLATE="$TERRAFORM_DIR/secrets.tfvars.template"
TFVARS_FILE="$TERRAFORM_DIR/terraform.tfvars"
SECRETS_FILE="$TERRAFORM_DIR/secrets.tfvars"

if [ ! -f "$INVENTORY_JSON" ]; then
  echo "Error: $INVENTORY_JSON not found. Run azure_full_inventory.sh first." >&2
  exit 1
fi
if [ ! -f "$TFVARS_TEMPLATE" ]; then
  echo "Error: $TFVARS_TEMPLATE not found. Ensure terraform.tfvars.template exists." >&2
  exit 1
fi
if [ ! -f "$SECRETS_TEMPLATE" ]; then
  echo "Error: $SECRETS_TEMPLATE not found. Ensure secrets.tfvars.template exists." >&2
  exit 1
fi
if [ ! -f "$CREDENTIALS_JSON" ]; then
  echo "Error: $CREDENTIALS_JSON not found. Ensure azure-credentials.json exists." >&2
  exit 1
fi

# Helper to extract a value from JSON, fallback to empty string
jq_get() {
  local query="$1"
  local file="$2"
  jq -r "$query // empty" "$file"
}

# Extract values from credentials and inventory
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id // .azure.subscriptionId // empty' "$CREDENTIALS_JSON")
# Try to get subscription name from resources or tags
SUBSCRIPTION_NAME=$(jq -r '.resources[] | select(.type=="Microsoft.Network/virtualNetworks") | .tags.billing_group // empty' "$INVENTORY_JSON" | head -n1)
[ -z "$SUBSCRIPTION_NAME" ] && SUBSCRIPTION_NAME=""

# Resource group: pick the one with tags or fallback to first
RESOURCE_GROUP=$(jq -r '.resourceGroups[] | select(.tags != null) | .name' "$INVENTORY_JSON" | head -n1)
[ -z "$RESOURCE_GROUP" ] && RESOURCE_GROUP=$(jq -r '.resourceGroups[0].name // empty' "$INVENTORY_JSON")

# Location: from resource group or vnet
LOCATION=$(jq -r '.resourceGroups[] | select(.name=="'$RESOURCE_GROUP'") | .location' "$INVENTORY_JSON")
[ -z "$LOCATION" ] && LOCATION=$(jq -r '.virtualNetworks[0].location // empty' "$INVENTORY_JSON")

# VNet
VNET_NAME=$(jq -r '.virtualNetworks[0].name // empty' "$INVENTORY_JSON")
VNET_ID=$(jq -r '.virtualNetworks[0].id // empty' "$INVENTORY_JSON")
VNET_ADDRESS_SPACE=$(jq -r '.virtualNetworks[0].addressSpace[0] // empty' "$INVENTORY_JSON")
DNS_SERVERS=$(jq -r '.virtualNetworks[0].dnsServers[0] // empty' "$INVENTORY_JSON")

# Subnet (if present)
SUBNET_NAME=$(jq -r '.virtualNetworks[0].subnets[0].name // empty' "$INVENTORY_JSON")
SUBNET_ADDRESS_PREFIXES=$(jq -r '.virtualNetworks[0].subnets[0].addressPrefix // empty' "$INVENTORY_JSON")

# Storage account (if present)
STORAGE_ACCOUNT_NAME=$(jq -r '.storageAccounts[0].name // empty' "$INVENTORY_JSON")
FILE_SHARE_NAME=$(jq -r '.fileShares[0].name // empty' "$INVENTORY_JSON")

# Common tags
ACCOUNT_CODING=$(jq -r '.resources[] | select(.type=="Microsoft.Network/virtualNetworks") | .tags.account_coding // empty' "$INVENTORY_JSON" | head -n1)
BILLING_GROUP=$(jq -r '.resources[] | select(.type=="Microsoft.Network/virtualNetworks") | .tags.billing_group // empty' "$INVENTORY_JSON" | head -n1)
MINISTRY_NAME=$(jq -r '.resources[] | select(.type=="Microsoft.Network/virtualNetworks") | .tags.ministry_name // empty' "$INVENTORY_JSON" | head -n1)
OWNER=$(jq -r '.resources[] | select(.type=="Microsoft.Network/networkSecurityGroups") | .tags.owner // empty' "$INVENTORY_JSON" | head -n1)
PROJECT=$(jq -r '.resources[] | select(.type=="Microsoft.Network/networkSecurityGroups") | .tags.project // empty' "$INVENTORY_JSON" | head -n1)
ENVIRONMENT=$(jq -r '.resources[] | select(.type=="Microsoft.Network/networkSecurityGroups") | .tags.environment // empty' "$INVENTORY_JSON" | head -n1)

# Populate terraform.tfvars from template
awk -v sub_name="$SUBSCRIPTION_NAME" \
    -v sub_id="$SUBSCRIPTION_ID" \
    -v rg="$RESOURCE_GROUP" \
    -v location="$LOCATION" \
    -v stg="$STORAGE_ACCOUNT_NAME" \
    -v share="$FILE_SHARE_NAME" \
    -v vnet="$VNET_NAME" \
    -v vnet_id="$VNET_ID" \
    -v vnet_addr="$VNET_ADDRESS_SPACE" \
    -v dns="$DNS_SERVERS" \
    -v subnet="$SUBNET_NAME" \
    -v subnet_addr="$SUBNET_ADDRESS_PREFIXES" \
    -v account_coding="$ACCOUNT_CODING" \
    -v billing_group="$BILLING_GROUP" \
    -v ministry_name="$MINISTRY_NAME" \
    -v owner="$OWNER" \
    -v project="$PROJECT" \
    -v environment="$ENVIRONMENT" \
    'BEGIN {OFS="\n"}
    /subscription_name/ {print "subscription_name = \"" sub_name "\""; next}
    /subscription_id/ {print "subscription_id = \"" sub_id "\""; next}
    /resource_group/ {print "resource_group = \"" rg "\""; next}
    /location/ {print "location = \"" location "\""; next}
    /storage_account_name/ {print "storage_account_name = \"" stg "\""; next}
    /file_share_name/ {print "file_share_name = \"" share "\""; next}
    /vnet_name/ {print "vnet_name = \"" vnet "\""; next}
    /vnet_id/ {print "vnet_id = \"" vnet_id "\""; next}
    /vnet_address_space/ {print "vnet_address_space = [\"" vnet_addr "\"]"; next}
    /dns_servers/ {print "dns_servers = \"" dns "\""; next}
    /subnet_name/ {print "subnet_name = \"" subnet "\""; next}
    /subnet_address_prefixes/ {print "subnet_address_prefixes = [\"" subnet_addr "\"]"; next}
    /account_coding/ {print "  account_coding  = \"" account_coding "\""; next}
    /billing_group/ {print "  billing_group   = \"" billing_group "\""; next}
    /ministry_name/ {print "  ministry_name   = \"" ministry_name "\""; next}
    /owner/ {print "  owner           = \"" owner "\""; next}
    /project/ {print "  project         = \"" project "\""; next}
    /environment/ {print "  environment     = \"" environment "\""; next}
    {print}
' "$TFVARS_TEMPLATE" > "$TFVARS_FILE"

CLIENT_ID=$(jq -r '.azure.ad.application.clientId // .github.clientId // empty' "$CREDENTIALS_JSON")
TENANT_ID=$(jq -r '.azure.ad.tenantId // .github.tenantId // empty' "$CREDENTIALS_JSON")
SUBSCRIPTION_ID=$(jq -r '.azure.subscription.id // .azure.subscriptionId // .github.subscriptionId // empty' "$CREDENTIALS_JSON")

awk -v client_id="$CLIENT_ID" \
    -v tenant_id="$TENANT_ID" \
    -v subscription_id="$SUBSCRIPTION_ID" \
    'BEGIN {in_block=0}
    /# client_id[[:space:]]*=.*$/ {if (!in_block) {print "client_id       = \"" client_id "\"  # App Registration''s Application (client) ID"; in_block=1} next}
    /# client_secret[[:space:]]*=.*$/ {if (in_block) {print "# client_secret   = \"<not needed for OIDC/GitHub Actions>\" # See OIDC documentation for details"} next}
    /# tenant_id[[:space:]]*=.*$/ {if (in_block) {print "tenant_id       = \"" tenant_id "\"  # Your Azure AD tenant ID"} next}
    /# subscription_id[[:space:]]*=.*$/ {if (in_block) {print "subscription_id = \"" subscription_id "\"  # Your Azure subscription ID"; in_block=0} next}
    {print}
    ' "$SECRETS_TEMPLATE" > "$SECRETS_FILE"

cat <<EOF
Populated:
  $TFVARS_FILE
  $SECRETS_FILE
with values from:
  $INVENTORY_JSON
  $CREDENTIALS_JSON
EOF
