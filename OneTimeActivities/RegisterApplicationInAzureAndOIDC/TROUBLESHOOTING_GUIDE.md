# Azure Files PoC - Troubleshooting Guide

This guide covers common issues and solutions for the Azure Files Proof of Concept onboarding process.

## Table of Contents

- [SSH Key Issues](#ssh-key-issues)
- [Azure Authentication Problems](#azure-authentication-problems)
- [Bastion Connection Failures](#bastion-connection-failures)
- [GitHub Actions Integration](#github-actions-integration)
- [Terraform State Issues](#terraform-state-issues)
- [Role Assignment Problems](#role-assignment-problems)
- [Resource Group Issues](#resource-group-issues)

## SSH Key Issues

### Problem: SSH key not found locally
```bash
# Check if SSH keys exist
ls -la ~/.ssh/id_rsa*

# If missing, regenerate using step11
./step11_create_ssh_key.sh
```

### Problem: SSH key permissions incorrect
```bash
# Fix permissions
chmod 600 ~/.ssh/id_rsa      # Private key
chmod 644 ~/.ssh/id_rsa.pub  # Public key
```

### Problem: SSH key not matching in terraform.tfvars
```bash
# Get current public key
cat ~/.ssh/id_rsa.pub

# Update terraform.tfvars with correct key
# Or regenerate key and update both terraform.tfvars and GitHub secrets
```

### Problem: SSH key fingerprint verification
```bash
# Check key fingerprint
ssh-keygen -lf ~/.ssh/id_rsa.pub

# Compare with what's deployed to Azure VM
```

## Azure Authentication Problems

### Problem: Azure CLI not logged in
```bash
# Check current login status
az account show

# Login if needed
az login

# Set correct subscription
az account set --subscription "<subscription-id>"
```

### Problem: Insufficient permissions for script execution
```bash
# Check current user's role assignments
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --all

# Verify you have Owner or Contributor role on subscription
```

### Problem: Service principal credentials expired
```bash
# Check app registration status
az ad app show --id "<client-id>"

# Rotate client secret if needed (step2 script handles this)
./step2_grant_subscription_level_permissions.sh
```

## Bastion Connection Failures

### Problem: Cannot connect to VM via Bastion
```bash
# 1. Verify VM is running
az vm get-instance-view --name <vm-name> \
  --resource-group <resource-group-name> \
  --query "instanceView.statuses[1].displayStatus" -o tsv

# 2. Check Bastion host status
az network bastion show --name <bastion-name> \
  --resource-group <resource-group-name> \
  --query "provisioningState" -o tsv

# 3. Get VM resource ID for connection
VM_ID=$(az vm show --name <vm-name> \
  --resource-group <resource-group-name> --query id -o tsv)

# 4. Try connection with debugging
az network bastion ssh --name <bastion-name> \
  --resource-group <resource-group-name> \
  --target-resource-id "$VM_ID" \
  --auth-type ssh-key --username <admin-username> \
  --ssh-key ~/.ssh/id_rsa --verbose
```

### Problem: Bastion host not found
```bash
# Check if bastion was deployed
az network bastion list --resource-group <resource-group-name>

# If missing, check Terraform deployment
cd terraform/environments/<environment>
terraform plan
terraform apply
```

### Problem: SSH key not installed on VM
```bash
# Check VM configuration
az vm show --name <vm-name> \
  --resource-group <resource-group-name> \
  --query "osProfile.linuxConfiguration.ssh.publicKeys" -o table

# If key missing, may need to recreate VM or use alternative access method
```

## GitHub Actions Integration

### Problem: GitHub secrets not set correctly
```bash
# List current secrets (requires GitHub CLI)
gh secret list

# Re-run secret setup script
./step5_add_github_secrets_cli.sh

# Manually verify critical secrets are present:
# - AZURE_CLIENT_ID
# - AZURE_TENANT_ID  
# - AZURE_SUBSCRIPTION_ID
# - ADMIN_SSH_KEY_PUBLIC
```

### Problem: OIDC federation not working
```bash
# Check federated credential configuration
az ad app federated-credential list --id "<client-id>"

# Re-run OIDC setup if needed
./step3_configure_github_oidc_federation.sh
```

### Problem: GitHub Actions failing with authentication errors
```bash
# Check if app registration has correct permissions
az role assignment list --assignee "<client-id>" --all

# Verify OIDC subject claim format in GitHub Actions logs
# Should match: repo:<owner>/<repo>:ref:refs/heads/<branch>
```

## Terraform State Issues

### Problem: Terraform state conflicts or corruption
```bash
# Use the state fix utility
./step8_fix_terraform_state.sh

# Or manually address specific issues:
cd terraform/environments/<environment>

# Check state status
terraform show

# Import existing resources if needed
terraform import azurerm_resource_group.main /subscriptions/<subscription-id>/resourceGroups/<resource-group-name>

# Force unlock if state is locked
terraform force-unlock LOCK_ID
```

### Problem: Terraform backend not accessible
```bash
# Verify storage account exists
az storage account show --name <storage-account-name> --resource-group <resource-group-name>

# Check storage account permissions
az role assignment list --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>"

# Re-run storage setup if needed
./step7_create_tfstate_storage_account.sh
```

### Problem: Terraform version conflicts
```bash
# Check Terraform version
terraform version

# Use tfenv to manage versions if needed
tfenv list
tfenv use 1.5.0  # or required version
```

## Role Assignment Problems

### Problem: Custom roles not found
```bash
# Check if custom roles exist
az role definition list --custom-role-only --query "[].{Name:roleName, Id:name}" -o table

# Re-create custom roles if missing
./step6.1_CreateCustomRole.sh
```

### Problem: Duplicate role assignments
```bash
# List all role assignments for principal
az role assignment list --assignee "your-principal-id" --all

# Clean up duplicates manually:
az role assignment delete --assignee "<principal-id>" --role "<role-name>" --scope "<scope>"

# Or re-run step2 which has cleanup logic
./step2_grant_subscription_level_permissions.sh
```

### Problem: Role assignments failing
```bash
# Check if you have sufficient permissions
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) \
  --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator']"

# Verify principal ID is correct
az ad sp show --id "<client-id>" --query id -o tsv
```

## Resource Group Issues

### Problem: Resource groups not created
```bash
# List current resource groups
az group list --query "[?starts_with(name, '<project-name>')].{Name:name, Location:location}" -o table

# Re-run resource group creation
./step6_create_resource_group.sh
```

### Problem: Resource group access denied
```bash
# Check permissions on resource group
az role assignment list --resource-group "<resource-group-name>"

# Re-assign roles if needed
./step6.2_assign_roles_to_resource_group.sh
```

## General Debugging Tips

### Enable verbose logging
Most Azure CLI commands support `--verbose` or `--debug` flags:
```bash
az group create --name test --location canadacentral --verbose
```

### Check Azure CLI configuration
```bash
# Show current configuration
az configure --list-defaults

# Reset if needed
az configure --defaults location=<azure-region>
```

### Verify script prerequisites
Before running any script, ensure:
1. Azure CLI is installed and logged in
2. Correct subscription is selected
3. Required permissions are available
4. All configuration files exist

### Get help for specific commands
```bash
# Azure CLI help
az --help
az group create --help

# Terraform help
terraform --help
terraform plan --help
```

## Emergency Recovery

### If onboarding process fails completely:
1. Run cleanup commands to remove partial state
2. Start fresh with step1
3. Use validation scripts to verify each step
4. Check logs and error messages carefully
5. Consult Azure portal for resource status

### If GitHub Actions are failing:
1. Check repository secrets are set correctly
2. Verify OIDC federation configuration
3. Review GitHub Actions logs for specific errors
4. Test Azure CLI authentication locally first

### If SSH access is lost:
1. Use Azure portal serial console
2. Reset VM admin password via Azure portal
3. Regenerate SSH keys and update VM
4. Use Azure Bastion browser-based connection as fallback

---

## Getting Additional Help

- Azure CLI documentation: https://docs.microsoft.com/en-us/cli/azure/
- Terraform Azure provider docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
- Azure Bastion documentation: https://docs.microsoft.com/en-us/azure/bastion/
- GitHub Actions Azure integration: https://docs.github.com/en/actions/deployment/deploying-to-your-cloud-provider/deploying-to-azure
