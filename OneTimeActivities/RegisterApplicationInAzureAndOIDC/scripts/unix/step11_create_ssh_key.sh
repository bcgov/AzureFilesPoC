#!/usr/bin/env bash
# step11_create_ssh_key.sh
# One-time activity: Generate SSH key pair for VM admin access (for onboarding and CI/CD)
#
# NOTE: For most users, you only need to add the public key (id_rsa.pub) to your GitHub repository secrets (e.g., ADMIN_SSH_KEY_PUBLIC).
# It is NOT required to add this key to secrets.tfvars unless you need it for local or non-GitHub automation.

KEY_PATH="${1:-$HOME/.ssh/id_rsa}"
EMAIL="${2:-$(whoami)@$(hostname)}"

if [[ -f "$KEY_PATH" && -f "$KEY_PATH.pub" ]]; then
  echo "✅ SSH key already exists at $KEY_PATH"
else
  echo "Generating new SSH key at $KEY_PATH"
  ssh-keygen -t rsa -b 4096 -C "$EMAIL" -f "$KEY_PATH" -N ""
fi

echo "\nPublic key (copy this to your GitHub secret, e.g., ADMIN_SSH_KEY_PUBLIC):"
cat "$KEY_PATH.pub"
echo "\nDone."
