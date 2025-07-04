#!/bin/bash

# CI/CD VM Readiness Check Script
# This script checks if the self-hosted runner VM is ready for GitHub Actions runner setup
#
# Usage: ./check-vm-ready.sh <resource-group> <vm-name> [bastion-name] [subscription-id]
#
# Examples:
#   ./check-vm-ready.sh rg-myproject-cicd-tools-dev vm-myproject-dev-01
#   ./check-vm-ready.sh rg-myproject-cicd-tools-dev vm-myproject-dev-01 bastion-myproject-dev-01
#   ./check-vm-ready.sh rg-myproject-cicd-tools-dev vm-myproject-dev-01 bastion-myproject-dev-01 12345678-1234-1234-1234-123456789012

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <resource-group> <vm-name> [bastion-name] [subscription-id]"
    echo ""
    echo "Arguments:"
    echo "  resource-group    Required. Resource group containing the VM"
    echo "  vm-name          Required. Name of the VM to check"
    echo "  bastion-name     Optional. Name of the Bastion host for connection instructions"
    echo "  subscription-id  Optional. Azure subscription ID for connection instructions"
    echo ""
    echo "Examples:"
    echo "  $0 rg-myproject-cicd-tools-dev vm-myproject-dev-01"
    echo "  $0 rg-myproject-cicd-tools-dev vm-myproject-dev-01 bastion-myproject-dev-01"
    echo "  $0 rg-myproject-cicd-tools-dev vm-myproject-dev-01 bastion-myproject-dev-01 12345678-1234-1234-1234-123456789012"
    exit 1
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "❌ Error: Missing required arguments"
    echo ""
    usage
fi

# Configuration from arguments
RESOURCE_GROUP="$1"
VM_NAME="$2"
BASTION_NAME="${3:-}"
SUBSCRIPTION_ID="${4:-}"

echo "🔍 Checking CI/CD VM readiness..."
echo "Resource Group: $RESOURCE_GROUP"
echo "VM Name: $VM_NAME"
echo ""

# Check VM power state
echo "1. Checking VM power state..."
VM_STATUS=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" --output tsv)
echo "   VM Power State: $VM_STATUS"

if [ "$VM_STATUS" != "VM running" ]; then
    echo "   ❌ VM is not running. Current state: $VM_STATUS"
    exit 1
else
    echo "   ✅ VM is running"
fi

# Check VM Agent status
echo ""
echo "2. Checking VM Agent status..."
VM_AGENT_STATUS=$(az vm get-instance-view --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query "instanceView.vmAgent.statuses[0].displayStatus" --output tsv)
echo "   VM Agent Status: $VM_AGENT_STATUS"

if [ "$VM_AGENT_STATUS" != "Ready" ]; then
    echo "   ❌ VM Agent is not ready. Current status: $VM_AGENT_STATUS"
    exit 1
else
    echo "   ✅ VM Agent is ready"
fi

# Check extension status
echo ""
echo "3. Checking extension status..."
EXTENSIONS_STATUS=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "$VM_NAME" --query "[].{Name:name, State:provisioningState}" --output table)
echo "$EXTENSIONS_STATUS"

# Count extensions in different states
TOTAL_EXTENSIONS=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "$VM_NAME" --query "length(@)" --output tsv)
SUCCEEDED_EXTENSIONS=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "$VM_NAME" --query "length([?provisioningState=='Succeeded'])" --output tsv)
FAILED_EXTENSIONS=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "$VM_NAME" --query "length([?provisioningState=='Failed'])" --output tsv)
UPDATING_EXTENSIONS=$(az vm extension list --resource-group "$RESOURCE_GROUP" --vm-name "$VM_NAME" --query "length([?provisioningState=='Updating'])" --output tsv)

echo ""
echo "Extension Summary:"
echo "   Total Extensions: $TOTAL_EXTENSIONS"
echo "   Succeeded: $SUCCEEDED_EXTENSIONS"
echo "   Still Updating: $UPDATING_EXTENSIONS"
echo "   Failed: $FAILED_EXTENSIONS"

# VM is ready if at least 3 critical extensions are succeeded or updating
# (AzureMonitorLinuxAgent, AzurePolicyforLinux, MDE.Linux are most critical)
READY_EXTENSIONS=$((SUCCEEDED_EXTENSIONS + UPDATING_EXTENSIONS))

if [ "$READY_EXTENSIONS" -ge 3 ]; then
    echo ""
    echo "✅ VM is ready for GitHub Actions runner setup!"
    echo "💡 Extensions may continue installing in the background - this is normal."
    echo ""
    
    # Show connection instructions if bastion info provided
    if [ -n "$BASTION_NAME" ]; then
        echo "🔗 Connect to VM via Bastion:"
        if [ -n "$SUBSCRIPTION_ID" ]; then
            echo "   az network bastion ssh \\"
            echo "     --name \"$BASTION_NAME\" \\"
            echo "     --resource-group \"$RESOURCE_GROUP\" \\"
            echo "     --target-resource-id \"/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM_NAME\" \\"
            echo "     --auth-type \"SSHKey\" \\"
            echo "     --username azureadmin \\"
            echo "     --ssh-key ~/.ssh/id_rsa"
        else
            echo "   az network bastion ssh \\"
            echo "     --name \"$BASTION_NAME\" \\"
            echo "     --resource-group \"$RESOURCE_GROUP\" \\"
            echo "     --target-resource-id \"/subscriptions/<YOUR-SUBSCRIPTION-ID>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/virtualMachines/$VM_NAME\" \\"
            echo "     --auth-type \"SSHKey\" \\"
            echo "     --username azureadmin \\"
            echo "     --ssh-key ~/.ssh/id_rsa"
        fi
    else
        echo "🔗 To connect to VM via Bastion, run:"
        echo "   $0 $RESOURCE_GROUP $VM_NAME <bastion-name> [subscription-id]"
    fi
    
    echo ""
    echo "📖 See terraform/environments/cicd/TROUBLESHOOTING.md for more commands"
    exit 0
else
    echo ""
    echo "⏳ VM is not ready yet. Extensions are still installing..."
    echo "⏰ Expected time: 15-30 minutes for BC Gov policy-mandated extensions"
    echo "🔄 Run this script again in 5-10 minutes"
    exit 1
fi
