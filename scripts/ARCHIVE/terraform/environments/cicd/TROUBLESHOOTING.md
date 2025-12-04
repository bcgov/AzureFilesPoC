# CI/CD Infrastructure Troubleshooting Guide

This guide provides diagnostic commands and troubleshooting steps for the CI/CD self-hosted runner infrastructure deployed in Azure.

## ⏰ Expected Deployment Timeline

**Total deployment time: ~45 minutes** (normal for BC Gov environments)
- **Infrastructure creation**: ~5 minutes (NSGs, subnets, Bastion, VM provisioning)  
- **Extension installation**: ~40 minutes (BC Gov policy-mandated security extensions)

## 🔧 VM Readiness Check Script

A helper script is provided to check VM status and readiness: `check-vm-ready.sh`

**Usage:**
```bash
# Basic check
./check-vm-ready.sh <resource-group> <vm-name>

# Full check with connection instructions  
./check-vm-ready.sh <resource-group> <vm-name> <bastion-name> <subscription-id>

# Example for this environment
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01 bastion-ag-pssg-azure-files-poc-dev-01 d321bcbe-c5e8-4830-901c-dab5fab3a834
```

**What the script checks:**
- VM power state and provisioning status
- VM Agent readiness
- Extension installation status and summary
- Connection instructions via Bastion

## Table of Contents
1. [Quick Health Check](#1-quick-health-check)
2. [Authentication and Subscription](#2-authentication-and-subscription)
3. [Resource Group and Resources](#3-resource-group-and-resources)
4. [Virtual Machine Diagnostics](#4-virtual-machine-diagnostics)
5. [Networking Diagnostics](#5-networking-diagnostics)
6. [Azure Bastion Connectivity](#6-azure-bastion-connectivity)
7. [GitHub Actions Runner Status](#7-github-actions-runner-status)
8. [Extension Installation Issues](#8-extension-installation-issues)
9. [Common Issues and Solutions](#9-common-issues-and-solutions)
10. [Emergency Recovery Commands](#10-emergency-recovery-commands)

---

## 1. Quick Health Check

### 1.1 Verify Azure Authentication
```bash
# Check current subscription and login status
az account show --query "{subscriptionId:id, tenantId:tenantId, name:name}" --output table

# List available subscriptions if needed
az account list --query "[].{Name:name, SubscriptionId:id, State:state}" --output table
```

### 1.2 Check All Project Resource Groups
```bash
# List all project-related resource groups
az group list --query "[?contains(name, 'ag-pssg-azure-files-poc')].{Name:name, Location:location, State:properties.provisioningState}" --output table
```

Expected output should show:
- `rg-ag-pssg-azure-files-poc-dev-tools` (CICD resources)
- `rg-ag-pssg-azure-files-poc-dev` (DEV environment)
- `rg-ag-pssg-azure-files-poc-tfstate-dev` (Terraform state)

---

## 2. Authentication and Subscription

### 2.1 Verify Subscription Access
```bash
# Check current subscription details
az account show

# Verify service principal permissions (if using one)
az role assignment list --assignee <SERVICE-PRINCIPAL-OBJECT-ID> --output table
```

### 2.2 Switch Subscription (if needed)
```bash
# Switch to correct subscription
az account set --subscription "<SUBSCRIPTION-ID>"
```

---

## 3. Resource Group and Resources

### 3.1 Check CICD Resource Group Contents
```bash
# List all resources in CICD tools resource group
az resource list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --query "[].{Name:name, Type:type, Location:location, State:properties.provisioningState}" \
  --output table
```

Expected resources:
- Virtual Machine (`Microsoft.Compute/virtualMachines`)
- Network Interface (`Microsoft.Network/networkInterfaces`)
- Network Security Groups (`Microsoft.Network/networkSecurityGroups`)
- Public IP (for Bastion) (`Microsoft.Network/publicIPAddresses`)
- Bastion Host (`Microsoft.Network/bastionHosts`)
- VM Extensions (`Microsoft.Compute/virtualMachines/extensions`)

### 3.2 Check Resource Provisioning States
```bash
# Check for any failed resources
az resource list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --query "[?properties.provisioningState!='Succeeded'].{Name:name, Type:type, State:properties.provisioningState}" \
  --output table
```

---

## 4. Virtual Machine Diagnostics

### 4.1 Check VM Status
```bash
# Get VM power state and provisioning state
az vm show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01" \
  --query "{Name:name, PowerState:powerState, ProvisioningState:provisioningState, VmId:vmId}" \
  --output table

# Get detailed VM information
az vm show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01" \
  --output json
```

### 4.2 Check VM Extensions Status
```bash
# List all VM extensions and their status
az vm extension list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --vm-name "vm-ag-pssg-azure-files-poc-dev-01" \
  --query "[].{Name:name, State:provisioningState, Publisher:publisher, Version:typeHandlerVersion}" \
  --output table
```

Common extensions in BC Gov environments:
- `AzureMonitorLinuxAgent` - Azure Monitor data collection
- `AzurePolicyforLinux` - Policy compliance monitoring
- `ChangeTracking-Linux` - Change tracking and inventory
- `DependencyAgentLinux` - Service dependency mapping
- `MDE.Linux` - Microsoft Defender for Endpoints

### 4.3 Get VM Boot Diagnostics
```bash
# Enable boot diagnostics if not already enabled
az vm boot-diagnostics enable --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01"

# Get boot diagnostics log
az vm boot-diagnostics get-boot-log --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01"
```

---

## 5. Networking Diagnostics

### 5.1 Check Subnets and NSG Associations
```bash
# List project subnets in the spoke VNet
az network vnet subnet list --resource-group "d5007d-dev-networking" \
  --vnet-name "d5007d-dev-vwan-spoke" \
  --query "[?contains(name, 'ag-pssg') || contains(name, 'Bastion') || contains(name, 'runner')].{Name:name, AddressPrefix:addressPrefix, NSG:networkSecurityGroup.id}" \
  --output table
```

### 5.2 Check VM Network Configuration
```bash
# Get VM network interface details
az vm show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01" \
  --query "networkProfile.networkInterfaces[0].id" --output tsv

# Get network interface configuration (use the ID from above)
az network nic show --ids <NETWORK-INTERFACE-ID> \
  --query "{Name:name, PrivateIP:ipConfigurations[0].privateIPAddress, Subnet:ipConfigurations[0].subnet.id}" \
  --output table
```

### 5.3 Check NSG Rules
```bash
# Check runner NSG rules
az network nsg rule list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --nsg-name "nsg-ag-pssg-azure-files-poc-github-runners" \
  --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, SourcePort:sourcePortRange, DestPort:destinationPortRange}" \
  --output table

# Check Bastion NSG rules
az network nsg rule list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --nsg-name "nsg-bastion-ag-pssg-azure-files-poc-dev-01" \
  --query "[].{Name:name, Priority:priority, Direction:direction, Access:access, Protocol:protocol, SourcePort:sourcePortRange, DestPort:destinationPortRange}" \
  --output table
```

### 5.4 Check Route Tables (if any)
```bash
# Check if subnets have route tables
az network vnet show --resource-group "d5007d-dev-networking" \
  --name "d5007d-dev-vwan-spoke" \
  --query "subnets[].{Name:name,RouteTable:routeTable.id}" \
  --output table

# If route tables exist, check routes
az network route-table list --resource-group "d5007d-dev-networking" --output table
```

---

## 6. Azure Bastion Connectivity

### 6.1 Check Bastion Status
```bash
# Verify Bastion host status
az network bastion show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --query "{Name:name, State:provisioningState, DnsName:dnsName, ScaleUnits:scaleUnits}" \
  --output table
```

### 6.2 Check Bastion Configuration
```bash
# Get Bastion configuration details
az network bastion show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --query "{EnableTunneling:enableTunneling, EnableIPConnect:enableIpConnect, EnableShareableLink:enableShareableLink}" \
  --output table
```

### 6.3 Connect to VM via Bastion (SSH)
```bash
# Prerequisites: Install required Azure CLI extensions
az extension add -n bastion
az extension add -n ssh

# Connect to VM via Bastion (replace <VM-RESOURCE-ID> with actual resource ID)
az network bastion ssh \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --target-resource-id "/subscriptions/<SUBSCRIPTION-ID>/resourceGroups/rg-ag-pssg-azure-files-poc-dev-tools/providers/Microsoft.Compute/virtualMachines/vm-ag-pssg-azure-files-poc-dev-01" \
  --auth-type "SSHKey" \
  --username "azureadmin" \
  --ssh-key ~/.ssh/id_rsa
```

---

## 7. GitHub Actions Runner Status

### 7.1 Check Runner Service on VM (via Bastion)
Once connected to the VM via Bastion, run these commands:

```bash
# Check if GitHub Actions runner service is running
sudo systemctl status actions.runner.* --no-pager

# Check runner configuration
ls -la /home/azureadmin/actions-runner/

# Check runner logs
sudo journalctl -u actions.runner.* -f --no-pager

# Check if runner is listening
netstat -tulpn | grep LISTEN
```

### 7.2 Re-register Runner (if needed)
```bash
# Remove existing runner registration
cd /home/azureadmin/actions-runner/
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove --token <GITHUB-REMOVAL-TOKEN>

# Re-register with new token
./config.sh --url https://github.com/<GITHUB-ORG>/<REPO-NAME> --token <GITHUB-REGISTRATION-TOKEN>
sudo ./svc.sh install
sudo ./svc.sh start
```

---

## 8. Extension Installation Issues

### 8.1 Monitor Extension Installation Progress
```bash
# Watch extension status in real-time
watch -n 30 'az vm extension list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" --vm-name "vm-ag-pssg-azure-files-poc-dev-01" --query "[].{Name:name, State:provisioningState}" --output table'
```

### 8.2 Get Extension Installation Details
```bash
# Get detailed status for a specific extension
az vm extension show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --vm-name "vm-ag-pssg-azure-files-poc-dev-01" \
  --name "AzurePolicyforLinux" \
  --query "{Name:name, State:provisioningState, Status:instanceView.statuses}" \
  --output json
```

### 8.3 Check VM Agent Status
```bash
# Verify VM agent is running (via Bastion connection)
systemctl status walinuxagent
sudo waagent -version
```

---

## 9. Common Issues and Solutions

### 9.1 Issue: VM Extensions Taking Too Long (>20 minutes)

**Symptoms:**
- Extensions stuck in "Creating" or "Updating" state
- VM provisioning state shows "Updating"
- Total deployment time exceeds 20 minutes

**Expected Timeline:**
- **Normal deployment time**: 40-45 minutes total
- **Infrastructure**: ~5 minutes (NSGs, subnets, Bastion, VM)
- **Extensions**: ~40 minutes (policy-mandated security extensions)

**Diagnosis:**
```bash
# Use the readiness check script (recommended)
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01

# Or check manually
az vm extension list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --vm-name "vm-ag-pssg-azure-files-poc-dev-01" \
  --query "[?provisioningState!='Succeeded'].{Name:name, State:provisioningState}" \
  --output table
```

**Root Cause:**
- BC Gov Azure Policy automatically installs 5+ security extensions
- Private networking causes slower download times  
- Extensions install sequentially to avoid conflicts

**Expected Extensions and Status:**
- ✅ `AzureMonitorLinuxAgent` - Should succeed (Azure Monitor data collection)
- ✅ `AzurePolicyforLinux` - Should succeed (Policy compliance monitoring)
- ✅ `ChangeTracking-Linux` - Should succeed (Change tracking and inventory)
- ✅ `MDE.Linux` - Should succeed (Microsoft Defender for Endpoints)
- ⚠️ `DependencyAgentLinux` - **May fail on Ubuntu 22.04.5 LTS (expected, non-critical)**

**Solution:**
- **Wait for completion** - Extensions may take 40+ minutes in BC Gov environments
- **DependencyAgentLinux failure is expected** and does not affect VM functionality
- VM is ready when 4 out of 5 extensions succeed (DependencyAgentLinux failure is normal)
- Do not force cancellation as it can cause issues

### 9.2 Issue: DependencyAgentLinux Extension Failure

**Symptoms:**
- `DependencyAgentLinux` shows "Failed" status
- Error message: "Unsupported distribution: Ubuntu 22.04.5 LTS"

**Diagnosis:**
```bash
az vm extension show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --vm-name "vm-ag-pssg-azure-files-poc-dev-01" \
  --name "DependencyAgentLinux" \
  --query "{Name:name, State:provisioningState, Status:instanceView.statuses}" \
  --output json
```

**Root Cause:**
- DependencyAgentLinux has limited Ubuntu version support
- Ubuntu 22.04.5 LTS is newer than what this agent supports
- This is a known limitation of the Microsoft Dependency Agent

**Solution:**
- **No action needed** - This is expected behavior
- VM functionality is **not affected** 
- GitHub Actions runner will work perfectly
- DependencyAgentLinux is optional (used for Service Map visualization)
- All critical security extensions should still succeed

### 9.3 Issue: Cannot Connect via Bastion

**Symptoms:**
- `az network bastion ssh` fails
- "enableTunneling" error messages

**Diagnosis:**
```bash
# Use the readiness check script (recommended)
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01 bastion-ag-pssg-azure-files-poc-dev-01 d321bcbe-c5e8-4830-901c-dab5fab3a834

# Or check manually
az network bastion show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --query "enableTunneling"

# Check CLI extensions
az extension list --query "[?name=='bastion' || name=='ssh'].{Name:name, Version:version}" --output table
```

**Solutions:**
```bash
# Update Azure CLI and extensions
az upgrade
az extension update --name bastion
az extension update --name ssh

# Enable tunneling in Bastion (if not enabled)
az network bastion update --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --enable-tunneling true
```

### 9.4 Issue: Terraform "AnotherOperationInProgress" Error

**Symptoms:**
- Terraform apply fails with Azure API error
- Multiple subnet operations running simultaneously

**Root Cause:**
- Multiple subnets being created on same VNet concurrently
- Azure VNet API doesn't support parallel subnet operations

**Solution:**
- Use `depends_on` in Terraform modules to ensure sequential creation
- The CICD configuration already implements this fix

### 9.5 Issue: GitHub Actions Runner Not Appearing

**Symptoms:**
- Runner doesn't show up in GitHub repository settings
- VM is running but not registered

**Diagnosis:**
```bash
# Use the readiness check script first
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01

# Then check via Bastion (if VM is ready)
# Check runner service status
sudo systemctl status actions.runner.*

# Check runner configuration files
ls -la /home/azureadmin/actions-runner/.runner
cat /home/azureadmin/actions-runner/.runner

# Check network connectivity to GitHub
curl -v https://api.github.com
```

**Solutions:**
1. Verify outbound HTTPS (443) is allowed in NSG
2. Check if GitHub token expired
3. Re-run runner registration script
4. Verify VM has outbound internet access

---

## 10. Emergency Recovery Commands

### 10.1 Force Stop/Start VM
```bash
# Force stop VM
az vm stop --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01"

# Start VM
az vm start --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01"

# Restart VM
az vm restart --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01"
```

### 10.2 Remove and Recreate Problematic Extensions
```bash
# Remove specific extension
az vm extension delete --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --vm-name "vm-ag-pssg-azure-files-poc-dev-01" \
  --name "AzurePolicyforLinux"

# Note: Policy-driven extensions will be automatically reinstalled
```

### 10.3 Clean Up and Redeploy
```bash
# Navigate to CICD directory
cd terraform/environments/cicd

# Destroy and recreate infrastructure
terraform destroy -var-file="../../terraform.tfvars" -auto-approve
terraform apply -var-file="../../terraform.tfvars" -auto-approve
```

---

## 11. Monitoring and Logs

### 11.1 Monitor Deployment Progress
```bash
# Watch resource states during deployment
watch -n 30 'az resource list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" --query "[].{Name:name, Type:type, State:properties.provisioningState}" --output table'
```

### 11.2 Check Azure Activity Logs
```bash
# Get recent activity for the resource group
az monitor activity-log list --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --start-time "2025-07-04T12:00:00Z" \
  --query "[].{Time:eventTimestamp, Status:status.value, Operation:operationName.value}" \
  --output table --max-events 20
```

---

## 12. Contact Information and Escalation

### When to Escalate:
- VM extensions fail after 60+ minutes (normal is 40-45 minutes)
- Bastion connectivity issues persist after CLI updates
- Network connectivity problems to GitHub or Azure services
- Terraform state corruption or backend access issues
- All extensions fail (some extension failures like DependencyAgentLinux are expected)

### Escalation Steps:
1. **Run the VM readiness check script** and collect output:
   ```bash
   ./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01 bastion-ag-pssg-azure-files-poc-dev-01 d321bcbe-c5e8-4830-901c-dab5fab3a834
   ```
2. Collect diagnostic output from relevant sections above
3. Check GitHub Actions workflow logs for additional context
4. Verify all onboarding prerequisites were completed
5. Contact platform team with collected diagnostics

### Important Notes:
- **45-minute deployment time is normal** for BC Gov environments
- **DependencyAgentLinux failure is expected** on Ubuntu 22.04.5 LTS
- **VM is ready when 4 out of 5 extensions succeed** (excluding DependencyAgentLinux)

---

## 13. Useful Reference Commands

### 13.1 VM Readiness Check Script Usage
```bash
# Quick readiness check (basic)
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01

# Full readiness check with connection instructions
./check-vm-ready.sh rg-ag-pssg-azure-files-poc-dev-tools vm-ag-pssg-azure-files-poc-dev-01 bastion-ag-pssg-azure-files-poc-dev-01 d321bcbe-c5e8-4830-901c-dab5fab3a834

# Generic usage pattern
./check-vm-ready.sh <resource-group> <vm-name> [bastion-name] [subscription-id]
```

### 13.2 Get Resource IDs for Scripts
### 13.2 Get Resource IDs for Scripts
```bash
# Get VM resource ID
az vm show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01" \
  --query "id" --output tsv

# Get subnet resource ID
az network vnet subnet show --resource-group "d5007d-dev-networking" \
  --vnet-name "d5007d-dev-vwan-spoke" \
  --name "snet-ag-pssg-azure-files-poc-github-runners" \
  --query "id" --output tsv
```

### 13.3 JSON Output for Detailed Analysis
```bash
# Get complete VM configuration
az vm show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "vm-ag-pssg-azure-files-poc-dev-01" \
  --output json > vm-config.json

# Get complete Bastion configuration  
az network bastion show --resource-group "rg-ag-pssg-azure-files-poc-dev-tools" \
  --name "bastion-ag-pssg-azure-files-poc-dev-01" \
  --output json > bastion-config.json
```

---

> **Note:** Replace placeholder values like `<SUBSCRIPTION-ID>`, `<SERVICE-PRINCIPAL-OBJECT-ID>`, etc. with actual values from your environment. These can be found in your `terraform.tfvars` file or GitHub repository variables/secrets.
>
> **Security:** Never include actual secrets, tokens, or sensitive IDs in documentation or scripts. Always use placeholder values and reference the appropriate secure storage location.
