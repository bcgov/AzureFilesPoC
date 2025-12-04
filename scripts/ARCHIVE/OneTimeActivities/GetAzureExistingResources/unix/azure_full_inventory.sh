#!/bin/bash
# azure_full_inventory.sh
#
# Comprehensive Azure inventory script for BC Gov and enterprise landing zones
#
# -----------------------------
# DEPENDENCIES
# -----------------------------
# This script requires the following tools to be installed and available in your PATH:
#   - az (Azure CLI)
#   - jq (JSON processor)
#   - timeout (GNU coreutils; on macOS, install with 'brew install coreutils' and ensure 'gtimeout' is aliased as 'timeout')
#
# Required Azure CLI extensions:
#   - virtual-wan (for vhub and related network commands)
#     Install with: az extension add --name virtual-wan
#   - You may need other extensions depending on your Azure resources.
#
# On macOS, you may need to run:
#   brew install azure-cli jq coreutils
#   echo 'alias timeout="gtimeout"' >> ~/.zshrc && source ~/.zshrc
#
# -----------------------------
# OUTPUTS
# -----------------------------
#   - .env/azure_full_inventory.json: Comprehensive JSON inventory of all Azure resources, including metadata and a normalized
#     onboarding/terraform section under the key 'onboarding'.
#   - .env/azure_inventory.log: Detailed log file of all operations, errors, and progress for troubleshooting.
#
# -----------------------------
# INTENDED USE
# -----------------------------
#   - This script is designed to discover and inventory all Azure resources in a subscription, including networking, security,
#     storage, and identity resources, in a robust and scalable way for large enterprise environments.
#   - The output JSON is used to drive onboarding automation and to populate Terraform files for infrastructure-as-code workflows.
#   - The onboarding section provides a normalized, automation-friendly structure for incremental onboarding, validation, and
#     Terraform resource generation.
#
#   For more details, see project documentation and onboarding/automation guides.
#
# -----------------------------



# --- Tool checks ---
for tool in az jq timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool '$tool' is not installed or not in PATH." >&2
        exit 1
    fi
done

# Function to resolve script location and set correct paths
resolve_script_path() {
    local script_path
    script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(dirname "$script_path")"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
    OUTPUT_DIR="$PROJECT_ROOT/.env"
    mkdir -p "$OUTPUT_DIR"
    OUTPUT_FILE="$OUTPUT_DIR/azure_full_inventory.json"
    LOG_FILE="$OUTPUT_DIR/azure_inventory.log"
    touch "$LOG_FILE"
}

# Debug print for PROJECT_ROOT and OUTPUT_FILE
resolve_script_path

echo "DEBUG: PROJECT_ROOT is set to: $PROJECT_ROOT" | tee -a "$LOG_FILE"
echo "DEBUG: OUTPUT_FILE is set to: $OUTPUT_FILE" | tee -a "$LOG_FILE"

# Suppress Azure CLI preview extension warning
az config set extension.dynamic_install_allow_preview=true 2>>"$LOG_FILE"

# Ensure user is logged in to Azure
if ! az account show > /dev/null 2>&1; then
    echo "Error: You are not logged in to Azure. Please run 'az login' and try again." | tee -a "$LOG_FILE"
    exit 1
fi

# Initialize an empty JSON object
> "$OUTPUT_FILE"
echo "{}" > "$OUTPUT_FILE"

# --- Cleanup trap for temp files ---
temp_files=()
cleanup() {
    for f in "${temp_files[@]}"; do
        [ -f "$f" ] && rm -f "$f"
    done
}
trap cleanup EXIT

# Function to merge JSON data into the output file
merge_json() {
    local key="$1"
    local data="$2"
    echo "[DEBUG] Merging $key into $OUTPUT_FILE..." | tee -a "$LOG_FILE"
    jq --arg key "$key" --argjson data "$data" '.[$key] = $data' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "[DEBUG] Merged $key into $OUTPUT_FILE" | tee -a "$LOG_FILE"
}

# Function to run commands with timeout and logging
run_command() {
    local cmd="$1"
    local key="$2"
    local tmp="$OUTPUT_DIR/${key}.json"
    temp_files+=("$tmp")
    echo "[DEBUG] Starting collection for $key..." | tee -a "$LOG_FILE"
    if timeout 300 bash -c "$cmd" > "$tmp" 2>>"$LOG_FILE"; then
        echo "[DEBUG] Finished collection for $key." | tee -a "$LOG_FILE"
        merge_json "$key" "$(cat "$tmp")"
    else
        echo "[DEBUG] Error or timeout collecting $key, writing empty array." | tee -a "$LOG_FILE"
        merge_json "$key" "[]"
    fi
    echo "[DEBUG] Completed processing for $key." | tee -a "$LOG_FILE"
}

# --- Parallel resource collection ---
{
    echo "[DEBUG] Starting parallel resource collection block..." | tee -a "$LOG_FILE"
    run_command 'az account show --query "{id:id, name:name, tenantId:tenantId, state:state}" --output json' "subscription" &
    run_command 'az account show --query "tenantId" --output json' "tenantId" &
    run_command 'az group list --query "[].{name:name, id:id, location:location, tags:tags}" --output json' "resourceGroups" &
    run_command 'az resource list --query "[].{id:id, name:name, type:type, resourceGroup:resourceGroup, location:location, sku:sku, tags:tags}" --output json' "resources" &
    run_command 'az network vnet list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, addressSpace:addressSpace.addressPrefixes, subnets:[subnets][].{id:id, name:name, addressPrefix:addressPrefix, nsgId:networkSecurityGroup.id, privateEndpointNetworkPolicies:privateEndpointNetworkPolicies, privateLinkServiceNetworkPolicies:privateLinkServiceNetworkPolicies}, dnsServers:dhcpOptions.dnsServers}" --output json' "virtualNetworks" &
    run_command 'az network nsg list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, securityRules:securityRules[].{name:name, direction:direction, access:access, protocol:protocol, sourceAddressPrefix:sourceAddressPrefix, destinationAddressPrefix:destinationAddressPrefix, sourcePortRange:sourcePortRange, destinationPortRange:destinationPortRange}}" --output json' "networkSecurityGroups" &
    run_command 'az network public-ip list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, ipAddress:ipAddress, sku:sku.name, publicIPAllocationMethod:publicIPAllocationMethod, dnsSettings:dnsSettings.domainNameLabel}" --output json' "publicIPAddresses" &
    run_command 'az network nic list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, privateIpAddress:ipConfigurations[].privateIPAddress, subnetId:ipConfigurations[].subnet.id, publicIpId:ipConfigurations[].publicIPAddress.id}" --output json' "privateIPAddresses" &
    run_command 'az network vpn-gateway list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, bgpSettings:bgpSettings, connections:[connections][].{name:name, id:id, remoteVnetId:remoteVnet.id, protocolType:protocolType}}" --output json' "vpnGateways" &
    run_command 'az network vpn-connection list --query "[].{id:id, name:name, resourceGroup:resourceGroup, connectionType:connectionType, vnetGatewayId:virtualNetworkGateway.id, expressRouteCircuitId:expressRouteCircuit.id, connectionStatus:connectionStatus}" --output json' "connections" &
    run_command 'az network route-table list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, routes:[routes][].{name:name, id:id, addressPrefix:addressPrefix, nextHopType:nextHopType, nextHopIpAddress:nextHopIpAddress}}" --output json' "routeTables" &
    run_command 'az network vhub list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, addressPrefix:addressPrefix, virtualWanId:virtualWan.id, routingState:routingState}" --output json' "virtualHubs" &
    run_command 'az network private-endpoint list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, subnetId:subnet.id, privateLinkServiceConnections:privateLinkServiceConnections[].{name:name, privateLinkServiceId:privateLinkServiceId, groupIds:groupIds}}" --output json' "privateEndpoints" &
    run_command 'az storage account list --query "[].{id:id, name:name, resourceGroup:resourceGroup, location:location, kind:kind, sku:sku.name}" --output json' "storageAccounts" &
    run_command 'az ad app list --query "[].{id:appId, displayName:displayName, identifierUris:identifierUris, createdDateTime:createdDateTime}" --output json' "registeredApplications" &
    run_command 'az role assignment list --query "[].{id:id, principalName:principalName, roleDefinitionName:roleDefinitionName, scope:scope, principalType:principalType}" --output json' "roleAssignments" &
    wait
    echo "[DEBUG] Completed parallel resource collection block." | tee -a "$LOG_FILE"
} >>"$LOG_FILE" 2>&1

# --- Optimized blob and file share queries (limit to 5 storage accounts) ---
echo "[DEBUG] Starting blob and file share collection..." | tee -a "$LOG_FILE"
STORAGE_ACCOUNTS=$(cat "$OUTPUT_DIR/storageAccounts.json" 2>/dev/null || echo "[]")
BLOBS=()
FILE_SHARES=()
MAX_ACCOUNTS=5
count=0
for account in $(echo "$STORAGE_ACCOUNTS" | jq -r '.[].name' | head -n $MAX_ACCOUNTS); do
    echo "Processing storage account $account ($((++count))/$MAX_ACCOUNTS)..." | tee -a "$LOG_FILE"
    key=$(timeout 30 az storage account keys list --account-name "$account" --query "[0].value" --output tsv 2>>"$LOG_FILE")
    if [ -n "$key" ]; then
        containers=$(timeout 60 az storage container list --account-name "$account" --account-key "$key" --query "[].name" --output json --num-results 50 2>>"$LOG_FILE" || echo "[]")
        for container in $(echo "$containers" | jq -r '.[]' 2>/dev/null); do
            blobs=$(timeout 60 az storage blob list --account-name "$account" --account-key "$key" --container-name "$container" --query "[].{name:name, container:containerName, lastModified:lastModified, contentLength:properties.contentLength}" --output json --num-results 100 2>>"$LOG_FILE" || echo "[]")
            BLOBS+=("$(jq -c --arg account "$account" --arg container "$container" '{account:$account, container:$container, blobs:.}' <<< "$blobs")")
        done
        shares=$(timeout 60 az storage share list --account-name "$account" --account-key "$key" --query "[].{name:name, id:id, lastModified:lastModified, quota:quota}" --output json --num-results 50 2>>"$LOG_FILE" || echo "[]")
        FILE_SHARES+=("$(jq -c --arg account "$account" '{account:$account, shares:.}' <<< "$shares")")
    else
        echo "Warning: Could not retrieve key for storage account $account, skipping..." | tee -a "$LOG_FILE"
    fi
done
merge_json "blobs" "$(jq -s '.' <<< "${BLOBS[*]}")"
merge_json "fileShares" "$(jq -s '.' <<< "${FILE_SHARES[*]}")"
echo "[DEBUG] Completed blob and file share collection." | tee -a "$LOG_FILE"

# --- Routes and routing intents (handle empty inputs gracefully) ---
echo "[DEBUG] Starting route and routing intent collection..." | tee -a "$LOG_FILE"
ROUTES=()
for rt in $(az network route-table list --query "[].{name:name, resourceGroup:resourceGroup}" --output json | jq -r '.[] | "\(.name) \(.resourceGroup)"'); do
    rt_name=$(echo "$rt" | awk '{print $1}')
    rg_name=$(echo "$rt" | awk '{print $2}')
    routes=$(timeout 60 az network route-table route list --route-table-name "$rt_name" --resource-group "$rg_name" --query "[].{id:id, name:name, resourceGroup:resourceGroup, routeTableId:routeTableId, addressPrefix:addressPrefix, nextHopType:nextHopType, nextHopIpAddress:nextHopIpAddress}" --output json 2>>"$LOG_FILE" || echo "[]")
    ROUTES+=("$routes")
done
merge_json "routes" "$(jq -s 'flatten' <<< "${ROUTES[*]}")"

echo "Collecting routing intents..." | tee -a "$LOG_FILE"
ROUTING_INTENTS=()
for vhub in $(az network vhub list --query "[].{name:name, resourceGroup:resourceGroup}" --output json | jq -r '.[] | "\(.name) \(.resourceGroup)"'); do
    vhub_name=$(echo "$vhub" | awk '{print $1}')
    rg_name=$(echo "$vhub" | awk '{print $2}')
    intents=$(timeout 60 az network vhub routing-intent list --vhub "$vhub_name" --resource-group "$rg_name" --query "[].{id:id, name:name, resourceGroup:resourceGroup, routingPolicies:routingPolicies[].{name:name, destinations:destinations, nextHop:nextHop}}" --output json 2>>"$LOG_FILE" || echo "[]")
    ROUTING_INTENTS+=("$intents")
done
merge_json "routingIntents" "$(jq -s 'flatten' <<< "${ROUTING_INTENTS[*]}")"
echo "[DEBUG] Completed route and routing intent collection." | tee -a "$LOG_FILE"

# --- Inject onboarding/terraform reference structure ---
echo "[DEBUG] Injecting onboarding structure..." | tee -a "$LOG_FILE"

# Validate required sections and inject empty arrays/objects if missing or invalid
for section in resourceGroups virtualNetworks networkSecurityGroups routeTables vpnGateways privateEndpoints; do
    # If the section is missing or not an array/object, set to [] (default for onboarding logic)
    if ! jq -e ". | has(\"$section\") and ((.${section} | type == \"array\") or (.${section} | type == \"object\"))" "$OUTPUT_FILE" >/dev/null 2>&1; then
        echo "[DEBUG] Section $section missing or invalid, injecting empty array/object." | tee -a "$LOG_FILE"
        jq --arg key "$section" '.[$key] = []' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # If the section is an array but contains nulls, filter them out
    if jq -e ".${section} | type == \"array\" and any(. == null)" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = (.[$key] | map(select(. != null)))' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # If the section is an object but contains nulls, filter them out
    if jq -e ".${section} | type == \"object\" and any(.[] == null)" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = (.[$key] | with_entries(select(.value != null)))' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # If the section is an empty string or null, set to []
    if jq -e ".${section} == null or .${section} == \"\"" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = []' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # If the section is an object but not valid, set to {}
    if jq -e ".${section} | type == \"object\" and (.${section} == null or .${section} == \"\")" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = {}' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # Defensive: if the section is not valid JSON, set to []
    if ! jq -e ".${section}" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = []' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # Defensive: if the section is not an array or object, set to []
    if ! jq -e ".${section} | type == \"array\" or type == \"object\"" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = []' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # Defensive: if the section is an array but not valid, set to []
    if ! jq -e ".${section} | type == \"array\"" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = []' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi
    # Defensive: if the section is an object but not valid, set to {}
    if ! jq -e ".${section} | type == \"object\"" "$OUTPUT_FILE" >/dev/null 2>&1; then
        jq --arg key "$section" '.[$key] = {}' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    fi

done

ONBOARDING_RESOURCE_GROUPS=$(jq '{resource_groups: ( .resourceGroups | map({
    (.name): {
      resource_group: .name,
      virtual_networks: (.name as $rg | (.virtualNetworks // [] | map(select(.resourceGroup == $rg)))),
      subnets: [],
      network_security_groups: (.name as $rg | (.networkSecurityGroups // [] | map(select(.resourceGroup == $rg)))),
      route_tables: (.name as $rg | (.routeTables // [] | map(select(.resourceGroup == $rg)))),
      private_dns_zones: [],
      firewalls: [],
      vpn_gateways: (.name as $rg | (.vpnGateways // [] | map(select(.resourceGroup == $rg)))),
      log_analytics_workspaces: [],
      key_vaults: [],
      managed_identities: [],
      private_endpoints: (.name as $rg | (.privateEndpoints // [] | map(select(.resourceGroup == $rg)))),
      diagnostic_settings: [],
      automation_accounts: []
    }
}) | add ) }' "$OUTPUT_FILE")

ONBOARDING=$(jq -n \
    --argjson subscription "$(jq '.subscription' "$OUTPUT_FILE")" \
    --arg tenant_id "$(jq -r '.subscription.tenantId' "$OUTPUT_FILE")" \
    --argjson groups "$ONBOARDING_RESOURCE_GROUPS" \
    '{
      subscription: $subscription,
      tenant: {id: $tenant_id},
      resource_groups: $groups.resource_groups
    }')

jq --argjson onboarding "$ONBOARDING" '.onboarding = $onboarding' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
echo "Onboarding structure injected into $OUTPUT_FILE under .onboarding" | tee -a "$LOG_FILE"
echo "[DEBUG] Onboarding structure injected." | tee -a "$LOG_FILE"

# --- Filter registeredApplications to only those associated with our subscription ---
SUBSCRIPTION_ID=$(jq -r '.resourceGroups[0].id' "$OUTPUT_FILE" | cut -d'/' -f3)
if [ -n "$SUBSCRIPTION_ID" ]; then
    jq --arg subid "$SUBSCRIPTION_ID" '
      .registeredApplications |= map(select(
        (.identifierUris[]? | tostring | contains($subid)) or
        (.id | tostring | contains($subid))
      ))
    ' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "[DEBUG] Filtered registeredApplications to only those associated with subscription $SUBSCRIPTION_ID" | tee -a "$LOG_FILE"
else
    echo "[WARN] Could not determine subscription ID for filtering registeredApplications." | tee -a "$LOG_FILE"
fi

# Final check
if [ $? -eq 0 ]; then
    echo "Inventory has been successfully written to $OUTPUT_FILE" | tee -a "$LOG_FILE"
else
    echo "Error: Failed to retrieve inventory, check $LOG_FILE for details" | tee -a "$LOG_FILE"
    exit 1
fi

# Display first 50 lines of output for verification
head -n 50 "$OUTPUT_FILE" | tee -a "$LOG_FILE"

# --- Merge all component JSON files into the main inventory file ---
ALL_COMPONENTS=(resourceGroups.json virtualNetworks.json networkSecurityGroups.json routeTables.json vpnGateways.json privateEndpoints.json publicIPAddresses.json privateIPAddresses.json storageAccounts.json registeredApplications.json roleAssignments.json blobs.json fileShares.json routes.json routingIntents.json)
MERGED_FILE="$OUTPUT_DIR/azure_full_inventory.json"

# Start with an empty JSON object
> "$MERGED_FILE"
echo '{}' > "$MERGED_FILE"

for comp in "${ALL_COMPONENTS[@]}"; do
    comp_key="${comp%.json}"
    comp_path="$OUTPUT_DIR/$comp"
    if [ -f "$comp_path" ]; then
        comp_data=$(cat "$comp_path")
        # Defensive: if file is empty or not valid JSON, use []
        if ! jq empty <<< "$comp_data" >/dev/null 2>&1; then
            comp_data="[]"
        fi
        jq --arg key "$comp_key" --argjson data "$comp_data" '.[$key] = $data' "$MERGED_FILE" > "$MERGED_FILE.tmp" && mv "$MERGED_FILE.tmp" "$MERGED_FILE"
    else
        # If file missing, inject empty array
        jq --arg key "$comp_key" '.[$key] = []' "$MERGED_FILE" > "$MERGED_FILE.tmp" && mv "$MERGED_FILE.tmp" "$MERGED_FILE"
    fi
    echo "[DEBUG] Merged $comp_key into $MERGED_FILE" | tee -a "$LOG_FILE"
done

# --- Ensure tags and all resource metadata are captured in the inventory ---
# Use az resource list to get all resources with full metadata (including tags)
ALL_RESOURCES_FILE="$OUTPUT_DIR/all-resources.json"
az resource list --output json > "$ALL_RESOURCES_FILE"

# Merge all-resources.json into the main inventory file under the key "resources"
if [ -s "$ALL_RESOURCES_FILE" ] && jq empty "$ALL_RESOURCES_FILE" >/dev/null 2>&1; then
    jq --argjson resources "$(cat "$ALL_RESOURCES_FILE")" '.resources = $resources' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
    echo "[DEBUG] Merged all-resources.json into $OUTPUT_FILE under .resources" | tee -a "$LOG_FILE"
else
    echo "[WARN] all-resources.json missing or invalid, skipping merge." | tee -a "$LOG_FILE"
fi

# --- Validate merged file is populated ---
if [ -s "$MERGED_FILE" ] && jq empty "$MERGED_FILE" >/dev/null 2>&1; then
    echo "[DEBUG] Merged inventory file $MERGED_FILE is valid and populated." | tee -a "$LOG_FILE"
    # Delete component files
    for comp in "${ALL_COMPONENTS[@]}"; do
        comp_path="$OUTPUT_DIR/$comp"
        if [ -f "$comp_path" ]; then
            rm -f "$comp_path"
            echo "[DEBUG] Deleted $comp_path" | tee -a "$LOG_FILE"
        fi
    done
else
    echo "[ERROR] Merged inventory file $MERGED_FILE is missing or invalid!" | tee -a "$LOG_FILE"
    exit 1
fi

# --- Cleanup: Remove all temp files in .env except azure-credentials.json, azure-credentials.template.json, and azure_full_inventory.json ---
for f in "$OUTPUT_DIR"/*.json; do
    fname=$(basename "$f")
    # Never delete the main inventory file or credentials files
    if [[ "$fname" == "azure-credentials.json" || "$fname" == "azure-credentials.template.json" || "$fname" == "azure_full_inventory.json" ]]; then
        continue
    fi
    # Defensive: skip if file is already deleted
    if [ ! -f "$f" ]; then
        continue
    fi
    rm -f "$f"
    echo "[DEBUG] Deleted $f (final cleanup)" | tee -a "$LOG_FILE"
done
