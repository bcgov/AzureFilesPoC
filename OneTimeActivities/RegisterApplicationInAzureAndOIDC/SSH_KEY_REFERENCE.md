# SSH Key Management Reference Guide

This guide provides comprehensive information about SSH key creation, management, and usage for the Azure Files PoC project.

## Quick Reference

### Extract Keys Locally
```bash
# Get public key (for GitHub secrets, terraform.tfvars)
cat ~/.ssh/id_rsa.pub

# Get private key (for bastion connections, local SSH)
cat ~/.ssh/id_rsa

# Copy public key to clipboard (macOS)
pbcopy < ~/.ssh/id_rsa.pub

# Copy private key to clipboard (macOS)
pbcopy < ~/.ssh/id_rsa
```

### Connect via Azure Bastion
```bash
# Basic connection template
az network bastion ssh --name <bastion-name> --resource-group <resource-group> \
  --target-resource-id <vm-resource-id> --auth-type ssh-key \
  --username <admin-username> --ssh-key ~/.ssh/id_rsa

# Example for this project
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id $(az vm show --name <vm-name> --resource-group <resource-group-name> --query id -o tsv) \
  --auth-type ssh-key --username <admin-username> --ssh-key ~/.ssh/id_rsa
```

## Detailed Key Management

### Key Generation
```bash
# Generate new RSA key pair (4096-bit for enhanced security)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Generate with passphrase (more secure but requires interactive input)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

# Generate with comment (helpful for identification)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "<project-name>-$(date +%Y%m%d)"
```

### Key Verification
```bash
# Check key fingerprint
ssh-keygen -lf ~/.ssh/id_rsa.pub

# Verify key format (should show ssh-rsa at beginning)
head -c 20 ~/.ssh/id_rsa.pub

# Check key strength (should show 4096 bits)
ssh-keygen -lf ~/.ssh/id_rsa.pub | awk '{print $1 " bits"}'

# Validate private key integrity
ssh-keygen -y -f ~/.ssh/id_rsa > /tmp/pubkey_from_private
diff ~/.ssh/id_rsa.pub /tmp/pubkey_from_private && echo "Keys match" || echo "Keys don't match"
rm /tmp/pubkey_from_private
```

### Key Permissions and Security
```bash
# Set correct permissions (critical for SSH to work)
chmod 600 ~/.ssh/id_rsa          # Private key: owner read/write only
chmod 644 ~/.ssh/id_rsa.pub      # Public key: world readable

# Verify permissions
ls -la ~/.ssh/id_rsa*

# Check SSH directory permissions (should be 700)
ls -ld ~/.ssh
chmod 700 ~/.ssh  # Fix if needed
```

### Key Backup and Recovery
```bash
# Backup keys to secure location
cp ~/.ssh/id_rsa* ~/Documents/ssh_backup/

# Create encrypted backup
tar -czf ssh_keys_backup.tar.gz -C ~/ .ssh/
gpg --symmetric --cipher-algo AES256 ssh_keys_backup.tar.gz

# Restore from backup
tar -xzf ssh_keys_backup.tar.gz -C ~/
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

## Azure-Specific Usage

### VM Resource ID Discovery
```bash
# Get VM resource ID for bastion connections
VM_ID=$(az vm show --name <vm-name> \
  --resource-group <resource-group-name> --query id -o tsv)
echo "VM Resource ID: $VM_ID"

# List all VMs in resource group
az vm list --resource-group <resource-group-name> \
  --query "[].{Name:name, ResourceId:id}" -o table
```

### Bastion Host Verification
```bash
# Check bastion host status
az network bastion show --name <bastion-name> \
  --resource-group <resource-group-name> \
  --query "{Name:name, State:provisioningState, Location:location}" -o table

# List all bastion hosts in subscription
az network bastion list --query "[].{Name:name, ResourceGroup:resourceGroup, State:provisioningState}" -o table
```

### VM SSH Configuration Verification
```bash
# Check VM OS profile (should show SSH public keys)
az vm show --name <vm-name> \
  --resource-group <resource-group-name> \
  --query "osProfile.linuxConfiguration.ssh.publicKeys" -o table

# Check VM admin username
az vm show --name <vm-name> \
  --resource-group <resource-group-name> \
  --query "osProfile.adminUsername" -o tsv

# Verify VM is running
az vm get-instance-view --name <vm-name> \
  --resource-group <resource-group-name> \
  --query "instanceView.statuses[1].displayStatus" -o tsv
```

## GitHub Integration

### Setting SSH Key as GitHub Secret
```bash
# Get public key for GitHub secret
PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)
echo "Add this as ADMIN_SSH_KEY_PUBLIC secret:"
echo "$PUBLIC_KEY"

# Using GitHub CLI to set secret
gh secret set ADMIN_SSH_KEY_PUBLIC --body "$(cat ~/.ssh/id_rsa.pub)"

# Verify secret was set
gh secret list | grep SSH
```

### SSH Key in Terraform Variables
```bash
# Update terraform.tfvars with current public key
cd /path/to/your/project/terraform
echo "admin_ssh_key_public = \"$(cat ~/.ssh/id_rsa.pub)\"" > temp_ssh_update.txt
echo "Update your terraform.tfvars with this line:"
cat temp_ssh_update.txt
rm temp_ssh_update.txt
```

## Advanced Bastion Operations

### Connection with Port Forwarding
```bash
# Forward local port through bastion to VM service
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key --username <admin-username> \
  --ssh-key ~/.ssh/id_rsa \
  -- -L 8080:localhost:80  # Forward local 8080 to VM port 80
```

### File Transfer via Bastion
```bash
# Note: Azure Bastion doesn't support SCP directly
# Use bastion SSH connection and then tools like rsync over SSH tunnel
# or use Azure File Share mounting for file transfers
```

### Connection Debugging
```bash
# Enable verbose SSH debugging
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key --username <admin-username> \
  --ssh-key ~/.ssh/id_rsa --verbose

# Check bastion connectivity
az network bastion show --name <bastion-name> \
  --resource-group <resource-group-name> \
  --query "{ProvisioningState:provisioningState, DnsName:dnsName}" -o table
```

## Alternative SSH Key Formats

### ED25519 Keys (Modern Alternative)
```bash
# Generate ED25519 key (smaller, faster, equally secure)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "<project-name>-ed25519"

# Use ED25519 key with bastion
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key --username <admin-username> \
  --ssh-key ~/.ssh/id_ed25519
```

### Multiple Key Management
```bash
# List all SSH keys
ls -la ~/.ssh/*.pub

# Use specific key with SSH config
cat >> ~/.ssh/config << EOF
Host azure-vm-bastion
    HostName azure-vm-via-bastion  # This would be handled by az command
    User <admin-username>
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
EOF
```

## Security Best Practices

### Key Rotation
```bash
# Regular key rotation (recommended every 90-180 days)
# 1. Generate new key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_new -N ""

# 2. Update GitHub secrets
gh secret set ADMIN_SSH_KEY_PUBLIC --body "$(cat ~/.ssh/id_rsa_new.pub)"

# 3. Update terraform.tfvars
# 4. Apply Terraform changes to update VM
# 5. Test new key
# 6. Replace old key files
mv ~/.ssh/id_rsa_new ~/.ssh/id_rsa
mv ~/.ssh/id_rsa_new.pub ~/.ssh/id_rsa.pub
```

### Key Security Monitoring
```bash
# Check for unauthorized key modifications
ls -la ~/.ssh/id_rsa* --time-style=full-iso

# Verify key hasn't been tampered with (if you have original fingerprint)
ssh-keygen -lf ~/.ssh/id_rsa.pub

# Monitor SSH auth logs on VM (when connected)
sudo tail -f /var/log/auth.log | grep ssh
```

### Passphrase Management
```bash
# Add passphrase to existing key
ssh-keygen -p -f ~/.ssh/id_rsa

# Remove passphrase (for automation - less secure)
ssh-keygen -p -f ~/.ssh/id_rsa -P 'old_passphrase' -N ''

# Use ssh-agent for passphrase caching
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
```

## Troubleshooting Common Issues

### Permission Errors
```bash
# Fix common permission issues
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chown $USER:$USER ~/.ssh/id_rsa*
```

### Key Format Issues
```bash
# Convert OpenSSH format to older format if needed
ssh-keygen -p -m PEM -f ~/.ssh/id_rsa

# Validate key format
file ~/.ssh/id_rsa
head -1 ~/.ssh/id_rsa.pub
```

### Connection Timeouts
```bash
# Increase connection timeout
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key --username <admin-username> \
  --ssh-key ~/.ssh/id_rsa \
  -- -o ConnectTimeout=60
```

---

For additional help, refer to:
- SSH man pages: `man ssh`, `man ssh-keygen`
- Azure Bastion documentation: https://docs.microsoft.com/en-us/azure/bastion/
- Azure CLI SSH documentation: https://docs.microsoft.com/en-us/cli/azure/network/bastion
