#!/bin/bash
# install-data-plane-tools.sh
# Installs additional tools for Azure Files/Blob, SMB, and data migration

set -e

# SMB/CIFS utilities for mounting Azure Files
sudo apt update
sudo apt install -y cifs-utils

# AzCopy for high-performance data transfer
wget -O azcopy.tar.gz https://aka.ms/downloadazcopy-v10-linux
rm -rf azcopy_linux_amd64_*
tar -xvf azcopy.tar.gz
sudo cp ./azcopy_linux_amd64_*/azcopy /usr/local/bin/
rm -rf azcopy.tar.gz azcopy_linux_amd64_*
azcopy --version

# Python 3 pip (for scripts/Azure SDKs)
sudo apt install -y python3-pip

# Node.js and npm (for GitHub Actions and scripts)
sudo apt install -y nodejs npm

# Install latest Terraform (1.12.2)
TERRAFORM_VERSION="1.12.2"
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
terraform --version

# Optional: Monitoring tools
sudo apt install -y htop ncdu

echo "All additional data plane tools installed."
