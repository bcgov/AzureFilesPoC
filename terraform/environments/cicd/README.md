# CI/CD Bootstrap: Self-Hosted GitHub Actions Runner

## 1. Overview and Purpose

This Terraform configuration bootstraps the necessary Azure infrastructure to host a **self-hosted GitHub Actions runner**.

Its primary purpose is to solve the `RequestDisallowedByPolicy` error encountered when deploying Azure resources from a standard GitHub-hosted runner.

### The Problem This Solves

Our Azure environment is governed by a security policy that **forbids creating resources (like Storage Accounts) with public network access enabled**.

*   Standard GitHub runners operate from the public internet.
*   When Terraform, running on a public runner, tries to create a storage account and then a file share inside it, it requires a network path.
*   If public access is disabled, the firewall blocks the runner, causing a `403 Forbidden` error.
*   If we try to enable public access, the Azure Policy blocks the action.

### The Solution: The Self-Hosted Runner

By deploying a Virtual Machine (VM) **inside our private Azure Spoke VNet**, we create a trusted "beachhead" for our CI/CD pipeline.

*   This VM is our **self-hosted runner**.
*   When a pipeline job runs on this VM, its network traffic originates from a **private IP address** within our VNet.
*   This allows Terraform to communicate with other Azure resources (like a storage account's private endpoint) over the private network, completely bypassing the public firewall and complying with Azure Policy.

This configuration creates the runner VM and all its dependencies.

---

## 2. Architecture Diagram

```mermaid
graph TD
    subgraph "Your Laptop"
        A[Developer] -- SSH Port 22<br/>(For initial setup only) --> D
    end

    subgraph "Azure Cloud"
        subgraph "Spoke VNet (e.g., d5007d-dev-vwan-spoke)"
            D[Runner VM<br>(gh-runner-dev-01)]
            PE[Private Endpoint for Storage]

            D -- Private Network Traffic --> PE
        end

        SA[Storage Account<br>(Public Access Disabled)]
        PE --- SA
    end

    subgraph "GitHub.com"
        G[GitHub Actions Service]
    end

    G -- HTTPS Port 443<br/>(Orchestrates Jobs) --> D
```

---

## 3. Azure Resources Created

This Terraform configuration will create the following objects in Azure:

*   **Resource Group (`azurerm_resource_group`):** A dedicated resource group (e.g., `rg-ag-pssg-cicd-tools-dev`) to contain all the runner's infrastructure, keeping it isolated and easy to manage.
*   **Public IP Address (`azurerm_public_ip`):** A static public IP address assigned to the VM. **Purpose:** To allow you to SSH into the VM from your local machine for initial setup or troubleshooting. This can be removed later for enhanced security if you have a VPN or Bastion host.
*   **Network Security Group (NSG) (`azurerm_network_security_group`):** A firewall for the VM's subnet. **Purpose:** It is configured with a rule to allow inbound SSH (port 22) traffic **only** from your specified home/office IP address. All other traffic is blocked.
*   **Linux Virtual Machine (`azurerm_linux_virtual_machine`):** The core resource. An Ubuntu VM that will be configured to run the GitHub Actions runner agent.
*   **Network Interface (NIC) (`azurerm_network_interface`):** The VM's virtual network card that connects it to the specified subnet in your Spoke VNet.

---

## 4. Prerequisites

Before running this configuration, you must have the following in place:

1.  **An Existing Spoke VNet and Subnet:** This configuration looks up an existing network. You must ensure the Spoke VNet and a dedicated subnet for the runner (e.g., `snet-github-runners`) have been created in Azure.
2.  **Tools Installed:** Azure CLI and Terraform must be installed on your local machine.
3.  **Azure Authentication:** You must be logged into the correct Azure subscription via `az login`.
4.  **SSH Key Pair:** You need an SSH key pair. The path to your public key (e.g., `~/.ssh/id_rsa.pub`) is required.
5.  **GitHub Personal Access Token (PAT):** If using the automated setup script (`runner_setup.sh`), you need a GitHub PAT with the `repo` scope. This is used by the script to register the new runner with your repository.

---

## 5. How to Use

This configuration should be run **once** from your local machine to bootstrap the runner.

1.  **Navigate to the Directory:**
    ```bash
    cd terraform/environments/cicd
    ```

2.  **Create `runner_setup.sh` (Optional, Recommended):**
    If you want to automate the runner installation, create the `runner_setup.sh` file in this directory and populate it with the setup commands.

3.  **Create/Update `terraform.tfvars`:**
    Ensure the `terraform.tfvars` file in this directory is populated with the correct values, especially `my_home_ip_address`.

4.  **Initialize Terraform:**
    This command connects Terraform to your remote state backend.
    ```bash
    terraform init -backend-config="resource_group_name=<your-tfstate-rg>" -backend-config="storage_account_name=<your-tfstate-sa>" -backend-config="container_name=<your-tfstate-container>"
    ```

5.  **Apply the Configuration:**
    Terraform will show you a plan and ask for confirmation before creating the resources.
    ```bash
    terraform apply -var-file=terraform.tfvars
    ```

---

## 6. Post-Deployment Steps

1.  **Verify the Runner in GitHub:**
    *   Navigate to your GitHub repository's **Settings > Actions > Runners**.
    *   You should see your new runner (e.g., `gh-runner-dev-01`) in the list with an "Idle" status.

2.  **Update Your Application Workflow:**
    *   In your main application deployment workflow file (e.g., `.github/workflows/deploy-dev.yml`), change the `runs-on` property for your jobs from `ubuntu-latest` to `self-hosted`.
    ```yaml
    jobs:
      terraform-deploy:
        runs-on: self-hosted
        # ... rest of your job steps
    ```

3.  **Commit and Push:**
    Commit the changes to your workflow file. The next time the pipeline runs, it will execute on your new, secure, self-hosted runner.