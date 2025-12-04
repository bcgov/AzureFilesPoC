#!/usr/bin/env bash
# step11_create_ssh_key.sh
# -----------------------------------------------------------------------------
# SUMMARY:
#   Generates an SSH key pair for secure access to Azure VMs through bastion servers.
#   This key enables admin access for onboarding, troubleshooting, and CI/CD operations.
#
# WHAT IT DOES:
#   - Creates an RSA 4096-bit SSH key pair (private and public keys)
#   - Uses no passphrase for automation compatibility
#   - Displays the public key for copying to GitHub secrets or Azure VM configuration
#
# USAGE:
#   bash step11_create_ssh_key.sh [key_path] [email]
#   
#   Examples:
#   bash step11_create_ssh_key.sh                                    # Uses defaults
#   bash step11_create_ssh_key.sh ~/.ssh/azure_vm_key user@company.com
#
# KEY USAGE SCENARIOS:
#   1. Azure VM Authentication: Public key added to VM during creation
#   2. Bastion Server Access: Key used for secure tunneling through Azure Bastion
#   3. GitHub Actions: Public key stored as repository secret (e.g., ADMIN_SSH_KEY_PUBLIC)
#   4. Local Development: Private key used for direct SSH connections
#
# HOW TO EXTRACT KEYS AFTER GENERATION:
#   
#   Get Public Key (for GitHub secrets, terraform.tfvars, VM creation):
#     cat ~/.ssh/id_rsa.pub
#   
#   Get Private Key (for local SSH connections, bastion access):
#     cat ~/.ssh/id_rsa
#   
#   Copy Public Key to Clipboard (macOS):
#     pbcopy < ~/.ssh/id_rsa.pub
#   
#   Copy Private Key to Clipboard (macOS):
#     pbcopy < ~/.ssh/id_rsa
#
# HOW TO CONNECT VIA AZURE BASTION:
#   
#   Basic Bastion SSH Connection:
#     az network bastion ssh --name <bastion-name> --resource-group <resource-group> \
#       --target-resource-id <vm-resource-id> --auth-type ssh-key \
#       --username <admin-username> --ssh-key ~/.ssh/id_rsa
#   
#   Example with Real Values:
#     az network bastion ssh --name pssg-azure-files-poc-dev-bastion \
#       --resource-group pssg-azure-files-poc-dev-rg \
#       --target-resource-id /subscriptions/YOUR-SUB-ID/resourceGroups/pssg-azure-files-poc-dev-rg/providers/Microsoft.Compute/virtualMachines/vm-name \
#       --auth-type ssh-key --username azureuser --ssh-key ~/.ssh/id_rsa
#   
#   Get VM Resource ID for Bastion:
#     az vm show --name <vm-name> --resource-group <resource-group> --query id -o tsv
#
# WHAT THIS ENABLES:
#   ✅ Secure VM Administration: Passwordless SSH access to Azure VMs
#   ✅ Bastion Connectivity: Secure tunneling through Azure Bastion Host
#   ✅ CI/CD Automation: GitHub Actions can SSH to VMs for deployments
#   ✅ Zero Trust Access: Key-based authentication eliminates password vulnerabilities
#   ✅ Emergency Recovery: Backup authentication method for locked-out scenarios
#   ✅ Multi-User Access: Same key can be deployed to multiple VMs/environments
#
# ADDITIONAL LOCAL KEY MANAGEMENT:
#   
#   Check Key Fingerprint (for verification):
#     ssh-keygen -lf ~/.ssh/id_rsa.pub
#   
#   Change Key Passphrase:
#     ssh-keygen -p -f ~/.ssh/id_rsa
#   
#   Verify Key Permissions (should be 600 for private, 644 for public):
#     ls -la ~/.ssh/id_rsa*
#     chmod 600 ~/.ssh/id_rsa      # Fix private key permissions if needed
#     chmod 644 ~/.ssh/id_rsa.pub  # Fix public key permissions if needed
#
# TROUBLESHOOTING BASTION CONNECTIONS:
#   
#   If bastion connection fails, check:
#   1. VM is running: az vm get-instance-view --name <vm> --resource-group <rg>
#   2. Bastion is provisioned: az network bastion show --name <bastion> --resource-group <rg>
#   3. SSH key exists locally: ls -la ~/.ssh/id_rsa*
#   4. VM has public key: Check during VM creation or in /home/azureuser/.ssh/authorized_keys
#   
#   Enable verbose SSH debugging:
#     az network bastion ssh --name <bastion> --resource-group <rg> \
#       --target-resource-id <vm-id> --auth-type ssh-key \
#       --username azureuser --ssh-key ~/.ssh/id_rsa --verbose
#   ✅ Terraform Integration: Public key automatically provisioned to VM authorized_keys
#   ✅ Multi-Environment Support: Same key works across dev/test/prod environments
#   ✅ Audit Trail: SSH connections logged and traceable via Azure monitoring
#   ✅ Emergency Access: Reliable method for troubleshooting and recovery operations

# SECURITY NOTES:
#   - RSA 4096-bit provides strong security for enterprise use
#   - No passphrase enables automation but requires secure private key storage
#   - Public key is safe to store in GitHub secrets or Azure configuration
#   - Private key should remain on secure, trusted machines only
# -----------------------------------------------------------------------------

KEY_PATH="${1:-$HOME/.ssh/id_rsa}"
EMAIL="${2:-$(whoami)@$(hostname)}"

if [[ -f "$KEY_PATH" && -f "$KEY_PATH.pub" ]]; then
  echo "✅ SSH key already exists at $KEY_PATH"
  
  # Check if existing key has a passphrase (non-interactive check)
  # This checks the key format without prompting for passphrase
  if ssh-keygen -y -f "$KEY_PATH" -P "" > /dev/null 2>&1; then
    echo "✅ Key has no passphrase (ready for automation)"
  else
    echo "⚠️  Key appears to have a passphrase."
    echo "   For automation compatibility, you may want to remove it:"
    echo "   ssh-keygen -p -f $KEY_PATH"
    echo "   (Enter old passphrase, then press Enter twice for empty new passphrase)"
  fi
else
  echo "Generating new SSH key at $KEY_PATH"
  ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH" -N "" #no passphrase required
  #ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH"  #requires user to enter a passphrase
fi

echo "\nPublic key (copy this to your GitHub secret, e.g., ADMIN_SSH_KEY_PUBLIC):"
cat "$KEY_PATH.pub"
echo "\nDone."
