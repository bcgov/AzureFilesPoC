#!/bin/bash
# complete-runner-setup.sh
#
# Usage:
#   1. Copy this script to your VM (use nano, scp, or paste).
#   2. Make it executable: chmod +x complete-runner-setup.sh
#   3. Run as a regular user with sudo privileges (NOT as root):
#        ./complete-runner-setup.sh
#
# If you are reinstalling or recovering a runner and see an error like:
#   "Cannot configure the runner because it is already configured."
# Do the following as the actions-runner user:
#   sudo su - actions-runner
#   cd ~/actions-runner
#   sudo ./svc.sh uninstall
#   ./config.sh remove
#   exit
# Then re-run this script as your regular user.
#
# This script will:
#   - Clean up any previous runner installation
#   - Install all required dependencies (Azure CLI, Terraform, AzCopy, cifs-utils, etc.)
#   - Create the actions-runner user if missing
#   - Download, configure, and install the GitHub Actions runner as a service
#   - Prompt for GitHub repo and registration token
#   - Start the runner and verify installation
#
# If you cannot use curl or scp, you can open nano and paste the script contents directly.
#
# For troubleshooting, see the README and TROUBLESHOOTING.md in this directory.
#
# A comprehensive script to perform a CLEAN installation of a GitHub Actions runner
# and all required dependencies for the BC Government Azure Files PoC, including:
# - Core runner agent
# - Azure CLI & Terraform
# - Data plane tools (AzCopy, cifs-utils, etc.)

set -e  # Exit on any error

# --- Configuration Variables ---
# Match the Terraform version from your .github/workflows/main.yml
TERRAFORM_VERSION="1.6.6"
# Use a recent, stable runner version
RUNNER_VERSION="2.317.0"
RUNNER_USER="actions-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_DIR="${RUNNER_HOME}/actions-runner"
GITHUB_ORG_OR_USER="bcgov"
GITHUB_REPO="AzureFilesPoC"
RUNNER_NAME="azure-files-poc-runner-$(hostname)"

# --- Logging and Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Script Functions ---

# Performs a clean wipe of any existing runner installation
cleanup_existing_runner() {
    log_info "Performing cleanup of any existing runner..."
    local service_name
    service_name=$(systemctl list-units --type=service --all | grep "actions.runner" | awk '{print $1}')

    if [[ -n "$service_name" ]]; then
        log_info "Found existing service: $service_name. Stopping and disabling..."
        sudo systemctl stop "$service_name" &>/dev/null || true
        sudo systemctl disable "$service_name" &>/dev/null || true
    fi

    if [[ -d "$RUNNER_DIR" ]];
    then
        log_info "Found existing runner directory. Attempting to remove previous runner configuration..."
        sudo -u "$RUNNER_USER" bash -c "cd '$RUNNER_DIR' && if [ -f ./config.sh ]; then ./config.sh remove --unattended || true; fi"
        log_info "Uninstalling service and deleting directory..."
        cd "$RUNNER_DIR"
        sudo ./svc.sh uninstall &>/dev/null || true
        cd ~
        sudo rm -rf "$RUNNER_DIR"
    fi
    log_success "Cleanup complete."
}

# Gathers required info from the user
collect_configuration() {
    log_info "Collecting configuration information..."
    read -p "GitHub Organization or Username [${GITHUB_ORG_OR_USER}]: " input_org
    GITHUB_ORG_OR_USER=${input_org:-$GITHUB_ORG_OR_USER}
    read -p "GitHub Repository Name [${GITHUB_REPO}]: " input_repo
    GITHUB_REPO=${input_repo:-$GITHUB_REPO}
    GITHUB_URL="https://github.com/${GITHUB_ORG_OR_USER}/${GITHUB_REPO}"

    echo
    echo "Please generate a new registration token from GitHub:"
    echo "1. Go to: ${GITHUB_URL}/settings/actions/runners/new"
    echo "2. Copy the registration token and paste it below."
    read -sp "Registration Token: " GITHUB_TOKEN; echo

    if [[ -z "$GITHUB_TOKEN" ]]; then log_error "Registration token is required."; exit 1; fi
}

# Installs all system-level dependencies for the runner and data plane operations
install_dependencies() {
    log_info "Updating package lists and installing all required dependencies..."
    sudo apt-get update
    local packages=("curl" "wget" "tar" "unzip" "git" "jq" "ca-certificates" "lsb-release" "gnupg" "cifs-utils" "python3-pip" "nodejs" "npm" "htop" "ncdu")
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            log_info "Installing $package..."
            sudo apt-get install -y "$package"
        else
            log_info "$package is already installed."
        fi
    done

    # Install Azure CLI if not present
    if ! command -v az &> /dev/null; then
        log_info "Installing Azure CLI..."
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    else
        log_info "Azure CLI is already installed."
    fi

    # Install Terraform if not present or wrong version
    if ! command -v terraform &> /dev/null || [[ "$(terraform --version | head -n 1)" != "Terraform v${TERRAFORM_VERSION}" ]]; then
        log_info "Installing Terraform v${TERRAFORM_VERSION}..."
        wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
        unzip -o "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" # -o for overwrite
        sudo mv terraform /usr/local/bin/
        rm "terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    else
        log_info "Terraform v${TERRAFORM_VERSION} is already installed."
    fi

    # Install AzCopy if not present
    if ! command -v azcopy &> /dev/null; then
        log_info "Installing AzCopy..."
        wget -O azcopy.tar.gz https://aka.ms/downloadazcopy-v10-linux
        local azcopy_dir=$(tar -tf azcopy.tar.gz | head -n 1 | cut -f1 -d"/")
        tar -xvf azcopy.tar.gz
        sudo cp "./${azcopy_dir}/azcopy" /usr/local/bin/
        rm -rf azcopy.tar.gz "${azcopy_dir}"
    else
        log_info "AzCopy is already installed."
    fi

    log_success "All dependencies are installed and up to date."
}

# Creates the dedicated service user for the runner
setup_runner_user() {
    log_info "Setting up runner user: ${RUNNER_USER}"
    if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
        sudo useradd -m -s /bin/bash "$RUNNER_USER"
        log_success "Created user: ${RUNNER_USER}"
    else
        log_info "User ${RUNNER_USER} already exists."
    fi
    log_info "Configuring passwordless sudo for ${RUNNER_USER}."
    echo "${RUNNER_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/90-${RUNNER_USER}"
    sudo chmod 440 "/etc/sudoers.d/90-${RUNNER_USER}"
}

# Installs and configures the runner agent itself
install_and_configure_runner() {
    log_info "Starting runner agent installation as user '${RUNNER_USER}'..."
    # Execute the installation steps as the runner user
    sudo -i -u "$RUNNER_USER" bash -s -- \
        "$RUNNER_DIR" "$RUNNER_VERSION" "$GITHUB_URL" "$GITHUB_TOKEN" "$RUNNER_NAME" <<'EOF'
    # This entire block runs as the 'actions-runner' user
    set -e
    RUNNER_DIR=$1
    RUNNER_VERSION=$2
    GITHUB_URL=$3
    GITHUB_TOKEN=$4
    RUNNER_NAME=$5

    echo "[Runner User] Creating directory: ${RUNNER_DIR}"
    mkdir -p "${RUNNER_DIR}"
    cd "${RUNNER_DIR}"

    echo "[Runner User] Downloading runner agent v${RUNNER_VERSION}..."
    curl -o "actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" -L \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

    echo "[Runner User] Extracting runner agent..."
    tar xzf "./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"

    echo "[Runner User] Configuring runner agent..."
    ./config.sh \
        --url "${GITHUB_URL}" \
        --token "${GITHUB_TOKEN}" \
        --name "${RUNNER_NAME}" \
        --labels self-hosted,linux,x64,azure-files-poc \
        --unattended \
        --replace

    echo "[Runner User] Installing service..."
    sudo ./svc.sh install

    echo "[Runner User] Starting service..."
    sudo ./svc.sh start
EOF
    log_success "Runner agent installation and configuration complete."
}

# --- Main Execution ---
main() {
    log_info "GitHub Actions Runner - Comprehensive Clean Installation"
    if [[ $EUID -eq 0 ]]; then log_error "This script cannot be run as root."; exit 1; fi

    cleanup_existing_runner
    collect_configuration
    install_dependencies
    setup_runner_user
    install_and_configure_runner

    echo
    log_success "🎉 VM setup is complete!"
    log_info "All tools are installed and the runner is configured."
    log_info "Verify the runner status in your GitHub repository, then re-run your workflow."
    echo "To check status on VM, run: systemctl status 'actions.runner.*'"
}

trap 'log_error "An error occurred. Installation failed on line $LINENO"' ERR
main "$@"