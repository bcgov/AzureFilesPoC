# Self-Hosted GitHub Actions Runner Setup

This guide provides step-by-step instructions for installing and configuring a GitHub Actions runner on your Azure VM to enable Azure Files PoC deployment from a private network.

## Overview

The self-hosted runner enables GitHub Actions workflows to execute from within your private Azure VNet, solving the BC Gov Azure Policy restrictions that prevent standard GitHub-hosted runners from creating storage accounts with private network access.

## Prerequisites

Before starting this setup, ensure you have completed:

✅ **Infrastructure Deployment:**
- [x] Azure AD application and OIDC setup (see `../RegisterApplicationInAzureAndOIDC/`)
- [x] Self-hosted runner VM deployed via Terraform (`terraform/environments/cicd/`)
- [x] VM is accessible via Azure Bastion
- [x] SSH key configured for passwordless access

✅ **Access Requirements:**
- [x] SSH access to the runner VM via Azure Bastion
- [x] GitHub repository admin permissions
- [x] Personal Access Token (PAT) with `repo` and `admin:org` scopes

## Quick Start (Recommended)

### 1. Copy and Run the All-in-One Setup Script

You can use the comprehensive setup script to automate the entire process:

```bash
# (On your VM)
nano complete-runner-setup.sh  # Or use scp/curl to copy the script
# Paste the script contents if using nano, then save and exit
chmod +x complete-runner-setup.sh
./complete-runner-setup.sh
```
- The script will prompt for your GitHub organization/user, repo, and registration token.
- It will clean up any previous runner, install all dependencies (including data plane tools), create the user, and configure the runner as a service.
- **Do NOT run as root.** Use a regular user with sudo privileges.

---

## Manual Steps (Advanced / Troubleshooting)

> **Note:** The previous scripts `install-github-runner.sh` and `install-data-plane-tools.sh` are now deprecated. Use `complete-runner-setup.sh` for all setup and recovery tasks.

### Step 1: Connect to Your Runner VM

Use the successful Bastion connection you've already established:

```bash
az network bastion ssh --name "<bastion-name>" \
  --resource-group "<resource-group>" \
  --target-resource-id "/subscriptions/YOUR-SUBSCRIPTION-ID/resourceGroups/<resource-group>/providers/Microsoft.Compute/virtualMachines/<vm-name>" \
  --auth-type ssh-key --username <admin-username> --ssh-key ~/.ssh/id_rsa
```



### Step 1.5: (If Needed) Use or Create the actions-runner User

First, try switching to the user and directory:

```bash
# Try switching to the actions-runner user and directory
sudo su - actions-runner
cd ~/actions-runner
```

If you get an error (e.g., user does not exist or directory missing), then create the user:

```bash
# Check if the user already exists
id actions-runner || getent passwd actions-runner

# Only run the following if the user does NOT exist:
sudo useradd -m -s /bin/bash actions-runner
sudo passwd actions-runner  # (set a password if needed)
sudo usermod -aG sudo actions-runner
sudo su - actions-runner
mkdir -p ~/actions-runner && cd ~/actions-runner
```

### Step 2: Download and Run Installation Script

Once connected to your VM:

```bash
# Download the installation script
curl -o install-github-runner.sh https://raw.githubusercontent.com/YourRepo/AzureFilesPoC/main/OneTimeActivities/SelfHostedRunnerSetup/install-github-runner.sh

# Make it executable
chmod +x install-github-runner.sh

# Run the installation (will prompt for required information)
./install-github-runner.sh
```

### Step 3: Register Runner with GitHub

The script will guide you through:
1. Generating a registration token from GitHub
2. Configuring the runner with your repository
3. Installing it as a system service
4. Starting the runner service

### Step 4: Verify Runner Registration

1. Go to your GitHub repository
2. Navigate to **Settings > Actions > Runners**
3. Verify your runner appears with "Idle" status

## Detailed Installation Guide

### Prerequisites Verification

Before installing the runner software, verify your VM environment:

```bash
# Check VM specifications
echo "VM Info:"
echo "Hostname: $(hostname)"
echo "OS: $(lsb_release -d)"
echo "CPU: $(nproc) cores"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $4}') available"

# Check network connectivity
echo -e "\nNetwork Connectivity:"
curl -s https://api.github.com/zen && echo " - GitHub API: ✅" || echo " - GitHub API: ❌"
curl -s https://management.azure.com/ -o /dev/null && echo " - Azure API: ✅" || echo " - Azure API: ❌"

# Check required tools
echo -e "\nRequired Tools:"
which curl >/dev/null && echo " - curl: ✅" || echo " - curl: ❌ (will install)"
which tar >/dev/null && echo " - tar: ✅" || echo " - tar: ❌ (will install)"
which systemctl >/dev/null && echo " - systemctl: ✅" || echo " - systemctl: ❌"
```

### Manual Installation Steps

If you prefer to install manually or need to troubleshoot the automated script:

#### 1. Install Dependencies

```bash
# Update package list
sudo apt update

# Install required packages
sudo apt install -y curl wget tar systemd

# Install additional dependencies for GitHub Actions
sudo apt install -y git jq unzip
```

#### 2. Create Runner User

```bash
# Create a dedicated user for the runner
sudo useradd -m -s /bin/bash actions-runner
sudo usermod -aG sudo actions-runner

# Switch to the runner user
sudo su - actions-runner
```

#### 3. Download GitHub Actions Runner

```bash
# Create runner directory
mkdir -p ~/actions-runner && cd ~/actions-runner

# Download the latest runner package (check GitHub for latest version)
RUNNER_VERSION="2.311.0"  # Update this to latest version
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract the installer
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
```

#### 4. Configure the Runner

```bash
# Generate registration token from GitHub
# Go to: https://github.com/YourOrg/AzureFilesPoC/settings/actions/runners/new
# Copy the token and replace YOUR_TOKEN below

export GITHUB_TOKEN="YOUR_TOKEN_HERE"
export GITHUB_URL="https://github.com/YourOrg/AzureFilesPoC"
export RUNNER_NAME="azure-files-poc-runner-$(hostname)"

# Configure the runner
./config.sh --url ${GITHUB_URL} --token ${GITHUB_TOKEN} --name ${RUNNER_NAME} --runnergroup default --labels self-hosted,linux,x64,azure-files-poc --work _work --replace
```

#### 5. Install as Service

```bash
# Install the runner as a systemd service
sudo ./svc.sh install actions-runner

# Start the service
sudo ./svc.sh start

# Enable auto-start on boot
sudo systemctl enable actions-runner.actions-runner.service
```

#### 6. Verify Installation

```bash
# Check service status
sudo ./svc.sh status

# View service logs
sudo journalctl -u actions-runner.actions-runner.service -f
```

### Configuration Templates

The runner can be customized using configuration templates in the `templates/` directory:

- **`runner-service.template`**: Systemd service configuration
- **`runner-config.template`**: Runner environment configuration

### Environment Configuration

#### Required Environment Variables

Create `/home/actions-runner/.env` with required variables:

```bash
# Azure Configuration
AZURE_SUBSCRIPTION_ID="YOUR-SUBSCRIPTION-ID"
AZURE_CLIENT_ID="YOUR-CLIENT-ID"
AZURE_TENANT_ID="YOUR-TENANT-ID"

# GitHub Configuration
GITHUB_REPOSITORY="YourOrg/AzureFilesPoC"
GITHUB_WORKSPACE="/home/actions-runner/_work/AzureFilesPoC/AzureFilesPoC"

# Terraform Configuration
ARM_USE_OIDC=true
ARM_SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"
ARM_CLIENT_ID="${AZURE_CLIENT_ID}"
ARM_TENANT_ID="${AZURE_TENANT_ID}"

# Path Configuration
PATH="/home/actions-runner/bin:${PATH}"
```

#### Install Required Tools for Azure Files PoC

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
TERRAFORM_VERSION="1.9.8"
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Verify installations
az --version
terraform --version
```

## Testing Your Runner

### Test 1: Basic Runner Connectivity

1. Go to GitHub Actions → "Run workflow"
2. Create a simple test workflow:

```yaml
name: Test Self-Hosted Runner
on: workflow_dispatch
jobs:
  test:
    runs-on: self-hosted
    steps:
      - name: Test basic functionality
        run: |
          echo "Runner hostname: $(hostname)"
          echo "Current user: $(whoami)"
          echo "Working directory: $(pwd)"
          echo "Available disk space: $(df -h / | tail -1)"
```

### Test 2: Azure Authentication

```yaml
name: Test Azure Authentication
on: workflow_dispatch
jobs:
  test-azure:
    runs-on: self-hosted
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Azure Login via OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Test Azure CLI
        run: |
          az account show
          az group list --query "[?name=='<your-resource-group>']" -o table
```

### Test 3: Terraform Operations

```yaml
name: Test Terraform
on: workflow_dispatch
jobs:
  test-terraform:
    runs-on: self-hosted
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Test Terraform
        run: |
          cd terraform/environments/dev
          terraform init
          terraform validate
          terraform plan -var-file="../../terraform.tfvars"
```

## Troubleshooting

### Common Issues

#### Runner Not Appearing in GitHub
```bash
# Check service status
sudo systemctl status actions-runner.actions-runner.service

# Check logs
sudo journalctl -u actions-runner.actions-runner.service -n 50

# Restart service
sudo systemctl restart actions-runner.actions-runner.service
```

#### Authentication Failures
```bash
# Verify OIDC token generation
curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq .

# Test Azure CLI authentication
az login --service-principal --username $AZURE_CLIENT_ID --tenant $AZURE_TENANT_ID --federated-token "$(curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)"
```

#### Network Connectivity Issues
```bash
# Test GitHub connectivity
curl -v https://api.github.com/

# Test Azure connectivity
curl -v https://management.azure.com/

# Check NSG rules
az network nsg rule list --nsg-name <your-nsg> --resource-group <your-rg> -o table
```

For detailed troubleshooting steps, see [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md).

## Security Considerations

### Runner Security Best Practices

1. **Isolated Environment**: Runner operates in dedicated VM with minimal access
2. **No Persistent Secrets**: Uses OIDC authentication, no stored credentials
3. **Limited Network Access**: Operates within private VNet with controlled egress
4. **Regular Updates**: Keep runner software and VM OS updated
5. **Monitoring**: Monitor runner logs and Azure activity

### Network Security

- Runner communicates outbound to GitHub (port 443)
- Inbound access only via Azure Bastion
- No public IP required for runner operation
- All Azure resource access via private endpoints

## Maintenance

### Regular Maintenance Tasks

```bash
# Update runner software (run monthly)
cd /home/actions-runner
sudo ./svc.sh stop
# Download and install latest version
sudo ./svc.sh start

# Update system packages (run weekly)
sudo apt update && sudo apt upgrade -y

# Clean up old workflow runs (run weekly)
cd /home/actions-runner/_work
find . -name "*.log" -mtime +7 -delete
```

### Monitoring Runner Health

```bash
# Check runner status
sudo ./svc.sh status

# Monitor resource usage
htop

# Check available disk space
df -h

# Monitor network connectivity
ping -c 4 api.github.com
```

## Next Steps

After successfully setting up your self-hosted runner:

1. **Update Workflow Files**: Modify your GitHub Actions workflows to use `runs-on: self-hosted`
2. **Deploy Azure Files Infrastructure**: Use the runner to deploy your Azure Files PoC resources
3. **Monitor and Maintain**: Regularly check runner health and update software

## Related Documentation

- [Azure VM Deployment Guide](../../terraform/environments/cicd/README.md)
- [GitHub Actions Workflow Setup](../GitHubActionsSetup/README.md)
- [OIDC Authentication Setup](../RegisterApplicationInAzureAndOIDC/README.md)
- [SSH Key Management](../RegisterApplicationInAzureAndOIDC/SSH_KEY_REFERENCE.md)

---

**Status**: ✅ Infrastructure deployed, ready for runner installation
**Last Updated**: July 4, 2025
**Next Action**: Connect to VM and run installation script
