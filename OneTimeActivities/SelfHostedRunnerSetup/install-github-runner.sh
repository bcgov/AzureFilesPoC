#!/bin/bash
# install-github-runner.sh
# Automated GitHub Actions Runner Installation Script for Azure Files PoC
# 
# This script sets up a self-hosted GitHub Actions runner on an Azure VM
# for BC Government Azure Files Proof of Concept deployment.

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root for security reasons."
   log_info "Please run as a regular user with sudo access."
   exit 1
fi

# Configuration variables
RUNNER_VERSION="2.311.0"  # GitHub Actions runner version
RUNNER_USER="actions-runner"
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"
GITHUB_ORG_OR_USER="YOUR_GITHUB_ORG"  # Update this
GITHUB_REPO="AzureFilesPoC"            # Update this
RUNNER_NAME="azure-files-poc-runner-$(hostname)"

log_info "Starting GitHub Actions Runner installation..."
log_info "Target runner: ${RUNNER_NAME}"

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check OS
    if ! command -v lsb_release &> /dev/null; then
        log_error "This script requires Ubuntu/Debian with lsb_release"
        exit 1
    fi
    
    local os_version=$(lsb_release -rs)
    log_info "Operating System: $(lsb_release -ds)"
    
    # Check minimum system requirements
    local cpu_cores=$(nproc)
    local memory_gb=$(free -g | awk '/^Mem:/{print $2}')
    local disk_space_gb=$(df --output=avail -BG / | tail -n1 | tr -d 'G')
    
    log_info "System specs: ${cpu_cores} CPU cores, ${memory_gb}GB RAM, ${disk_space_gb}GB available disk"
    
    if [[ $cpu_cores -lt 2 ]]; then
        log_warning "Recommended: At least 2 CPU cores (current: ${cpu_cores})"
    fi
    
    if [[ $memory_gb -lt 4 ]]; then
        log_warning "Recommended: At least 4GB RAM (current: ${memory_gb}GB)"
    fi
    
    if [[ $disk_space_gb -lt 20 ]]; then
        log_error "Insufficient disk space. Need at least 20GB (current: ${disk_space_gb}GB)"
        exit 1
    fi
    
    # Check network connectivity
    log_info "Testing network connectivity..."
    if ! curl -s --max-time 10 https://api.github.com/zen > /dev/null; then
        log_error "Cannot reach GitHub API. Check network connectivity."
        exit 1
    fi
    log_success "GitHub API connectivity: OK"
    
    if ! curl -s --max-time 10 https://management.azure.com/ > /dev/null; then
        log_warning "Cannot reach Azure API. This may affect Azure CLI operations."
    else
        log_success "Azure API connectivity: OK"
    fi
}

# Function to collect user input
collect_configuration() {
    log_info "Collecting configuration information..."
    
    # Get GitHub repository information
    echo
    echo "=== GitHub Repository Configuration ==="
    read -p "GitHub Organization or Username [${GITHUB_ORG_OR_USER}]: " input_org
    GITHUB_ORG_OR_USER=${input_org:-$GITHUB_ORG_OR_USER}
    
    read -p "GitHub Repository Name [${GITHUB_REPO}]: " input_repo
    GITHUB_REPO=${input_repo:-$GITHUB_REPO}
    
    GITHUB_URL="https://github.com/${GITHUB_ORG_OR_USER}/${GITHUB_REPO}"
    
    echo
    echo "=== Runner Configuration ==="
    read -p "Runner Name [${RUNNER_NAME}]: " input_runner_name
    RUNNER_NAME=${input_runner_name:-$RUNNER_NAME}
    
    # Get registration token
    echo
    echo "=== GitHub Registration Token ==="
    echo "Please generate a registration token:"
    echo "1. Go to: ${GITHUB_URL}/settings/actions/runners/new"
    echo "2. Copy the token from the configuration command"
    echo "3. Paste it below"
    echo
    read -p "Registration Token: " GITHUB_TOKEN
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "Registration token is required"
        exit 1
    fi
    
    # Validate token format (should be a long alphanumeric string)
    if [[ ! "$GITHUB_TOKEN" =~ ^[A-Z0-9]{29}$ ]]; then
        log_warning "Token format doesn't match expected pattern. Continuing anyway..."
    fi
    
    echo
    echo "=== Configuration Summary ==="
    echo "GitHub URL: ${GITHUB_URL}"
    echo "Runner Name: ${RUNNER_NAME}"
    echo "Runner User: ${RUNNER_USER}"
    echo "Runner Directory: ${RUNNER_DIR}"
    echo
    read -p "Continue with installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi
}

# Function to install dependencies
install_dependencies() {
    log_info "Installing system dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install required packages
    local packages=(
        "curl"
        "wget" 
        "tar"
        "unzip"
        "git"
        "jq"
        "systemd"
        "ca-certificates"
        "lsb-release"
        "gnupg"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            sudo apt install -y "$package"
        else
            log_info "$package is already installed"
        fi
    done
    
    # Install Azure CLI
    if ! command -v az &> /dev/null; then
        log_info "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        log_info "Azure CLI is already installed"
    fi
    
    # Install Terraform
    if ! command -v terraform &> /dev/null; then
        log_info "Installing Terraform..."
        local terraform_version="1.9.8"
        wget -q https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip
        unzip -q terraform_${terraform_version}_linux_amd64.zip
        sudo mv terraform /usr/local/bin/
        rm terraform_${terraform_version}_linux_amd64.zip
    else
        log_info "Terraform is already installed"
    fi
    
    log_success "Dependencies installed successfully"
}

# Function to create runner user
create_runner_user() {
    log_info "Setting up runner user: ${RUNNER_USER}"
    
    # Create user if it doesn't exist
    if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
        sudo useradd -m -s /bin/bash "$RUNNER_USER"
        sudo usermod -aG sudo "$RUNNER_USER"
        log_success "Created user: ${RUNNER_USER}"
    else
        log_info "User ${RUNNER_USER} already exists"
    fi
    
    # Set up sudo access without password for specific commands
    local sudoers_file="/etc/sudoers.d/${RUNNER_USER}"
    if [[ ! -f "$sudoers_file" ]]; then
        echo "${RUNNER_USER} ALL=(ALL) NOPASSWD: /bin/systemctl, /usr/bin/apt, /usr/bin/docker" | sudo tee "$sudoers_file"
        sudo chmod 440 "$sudoers_file"
        log_success "Configured sudo access for ${RUNNER_USER}"
    fi
}

# Function to download and install runner
install_runner() {
    log_info "Installing GitHub Actions runner..."
    
    # Switch to runner user for installation
    sudo -u "$RUNNER_USER" bash << EOF
set -e

# Create runner directory
mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

# Download runner if not already present
if [[ ! -f "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" ]]; then
    echo "Downloading GitHub Actions runner v${RUNNER_VERSION}..."
    curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz -L \\
        https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
fi

# Extract runner if not already extracted
if [[ ! -f "config.sh" ]]; then
    echo "Extracting runner..."
    tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
fi

# Install dependencies
if [[ -f "bin/installdependencies.sh" ]]; then
    echo "Installing runner dependencies..."
    sudo ./bin/installdependencies.sh
fi

EOF
    
    log_success "Runner binaries installed"
}

# Function to configure runner
configure_runner() {
    log_info "Configuring GitHub Actions runner..."
    
    sudo -u "$RUNNER_USER" bash << EOF
set -e
cd "${RUNNER_DIR}"

# Remove existing configuration if present
if [[ -f ".runner" ]]; then
    echo "Removing existing runner configuration..."
    ./config.sh remove --token "${GITHUB_TOKEN}" || true
fi

# Configure the runner
echo "Configuring runner with GitHub..."
./config.sh \\
    --url "${GITHUB_URL}" \\
    --token "${GITHUB_TOKEN}" \\
    --name "${RUNNER_NAME}" \\
    --runnergroup default \\
    --labels self-hosted,linux,x64,azure-files-poc,bc-gov \\
    --work _work \\
    --replace \\
    --unattended

EOF
    
    log_success "Runner configured successfully"
}

# Function to install runner as service
install_service() {
    log_info "Installing runner as systemd service..."
    
    sudo -u "$RUNNER_USER" bash << EOF
set -e
cd "${RUNNER_DIR}"

# Install the service
sudo ./svc.sh install "${RUNNER_USER}"

EOF
    
    # Enable and start the service
    sudo systemctl enable "actions-runner.${RUNNER_USER}.service"
    sudo systemctl start "actions-runner.${RUNNER_USER}.service"
    
    # Wait a moment for service to start
    sleep 5
    
    # Check service status
    if sudo systemctl is-active --quiet "actions-runner.${RUNNER_USER}.service"; then
        log_success "Runner service installed and started successfully"
    else
        log_error "Runner service failed to start"
        sudo systemctl status "actions-runner.${RUNNER_USER}.service"
        exit 1
    fi
}

# Function to create environment configuration
create_environment_config() {
    log_info "Creating environment configuration..."
    
    local env_file="${RUNNER_DIR}/.env"
    
    sudo -u "$RUNNER_USER" bash << EOF
cat > "${env_file}" << 'EOL'
# Azure Configuration for GitHub Actions
# Generated by install-github-runner.sh on $(date)

# Azure OIDC Authentication
ARM_USE_OIDC=true
ARM_SUBSCRIPTION_ID="\${AZURE_SUBSCRIPTION_ID}"
ARM_CLIENT_ID="\${AZURE_CLIENT_ID}"
ARM_TENANT_ID="\${AZURE_TENANT_ID}"

# GitHub Configuration
GITHUB_REPOSITORY="${GITHUB_ORG_OR_USER}/${GITHUB_REPO}"
GITHUB_WORKSPACE="${RUNNER_DIR}/_work/${GITHUB_REPO}/${GITHUB_REPO}"

# Path Configuration
PATH="/home/${RUNNER_USER}/bin:/usr/local/bin:\${PATH}"

# Runner Configuration
RUNNER_NAME="${RUNNER_NAME}"
RUNNER_LABELS="self-hosted,linux,x64,azure-files-poc,bc-gov"
EOL

chmod 640 "${env_file}"
EOF
    
    log_success "Environment configuration created"
}

# Function to verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    # Check service status
    if sudo systemctl is-active --quiet "actions-runner.${RUNNER_USER}.service"; then
        log_success "✅ Runner service is active"
    else
        log_error "❌ Runner service is not active"
        return 1
    fi
    
    # Check if runner appears in GitHub
    echo
    log_info "Please verify the runner appears in GitHub:"
    log_info "1. Go to: ${GITHUB_URL}/settings/actions/runners"
    log_info "2. Look for runner: ${RUNNER_NAME}"
    log_info "3. Status should be 'Idle'"
    
    # Show service logs
    echo
    log_info "Recent service logs:"
    sudo journalctl -u "actions-runner.${RUNNER_USER}.service" -n 10 --no-pager
    
    echo
    log_info "To view live logs, run:"
    log_info "sudo journalctl -u actions-runner.${RUNNER_USER}.service -f"
}

# Function to show next steps
show_next_steps() {
    echo
    echo "========================================"
    echo "🎉 Installation Complete!"
    echo "========================================"
    echo
    echo "Next Steps:"
    echo "1. Verify runner in GitHub: ${GITHUB_URL}/settings/actions/runners"
    echo "2. Update your workflows to use: runs-on: self-hosted"
    echo "3. Test with a simple workflow"
    echo
    echo "Useful Commands:"
    echo "- Check status: sudo systemctl status actions-runner.${RUNNER_USER}.service"
    echo "- View logs: sudo journalctl -u actions-runner.${RUNNER_USER}.service -f"
    echo "- Restart service: sudo systemctl restart actions-runner.${RUNNER_USER}.service"
    echo
    echo "Runner Configuration:"
    echo "- Name: ${RUNNER_NAME}"
    echo "- Labels: self-hosted,linux,x64,azure-files-poc,bc-gov"
    echo "- Working Directory: ${RUNNER_DIR}/_work"
    echo
    echo "Documentation:"
    echo "- Setup Guide: OneTimeActivities/SelfHostedRunnerSetup/README.md"
    echo "- Troubleshooting: OneTimeActivities/SelfHostedRunnerSetup/TROUBLESHOOTING.md"
    echo
}

# Main execution
main() {
    log_info "GitHub Actions Runner Installation Script"
    log_info "For Azure Files PoC - BC Government"
    echo
    
    check_prerequisites
    collect_configuration
    install_dependencies
    create_runner_user
    install_runner
    configure_runner
    install_service
    create_environment_config
    verify_installation
    show_next_steps
    
    log_success "Installation completed successfully!"
}

# Error handling
trap 'log_error "Installation failed on line $LINENO"' ERR

# Run main function
main "$@"
