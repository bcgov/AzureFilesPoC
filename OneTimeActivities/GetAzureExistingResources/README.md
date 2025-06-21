# GetAzureExistingResources

This folder contains scripts to automatically discover and record key Azure resources that are pre-provisioned in your BC Gov Azure Landing Zone subscription (such as VNets, subnets, NSGs, and resource groups).

## Purpose
- **Automate discovery** of existing Azure infrastructure so you can reference these resources in Terraform and onboarding scripts, rather than creating duplicates.
- **Populate** the `.env/azure_full_inventory.json` file with resource IDs, names, tags, and other metadata for use by all onboarding, validation, and Terraform modules.
- **Support robust, modern inventory** with a single, comprehensive JSON file for automation and onboarding.
- **Cross-platform support:** Both Bash (Unix/macOS) and PowerShell (Windows) automation scripts are provided and maintained.

## Usage
1. Run the new inventory script for your platform:
   - **Unix/macOS:** `../OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh`
   - **Windows:** `../OneTimeActivities/GetAzureExistingResources/windows/azure_full_inventory.ps1`
2. The script will automatically collect all relevant Azure resources in your subscription, including resource groups, VNets, subnets, NSGs, route tables, private endpoints, tags, and more.
3. The script outputs a single file: `.env/azure_full_inventory.json` containing all discovered resource information, normalized for onboarding and Terraform automation.
4. Temporary files are cleaned up automatically. The main inventory file and credentials are preserved.
5. The output JSON file is **ignored by git** and should be treated as sensitive (contains resource IDs and metadata).

## What Resource Types Are Discovered?

The script will attempt to discover and record the following types of pre-provisioned resources commonly found in BC Gov and other secure Azure landing zones:

- Resource Groups
- Virtual Networks (VNets)
- Subnets
- Network Security Groups (NSGs)
- Route Tables
- Private DNS Zones
- Azure Firewalls
- VPN/ExpressRoute Gateways
- Log Analytics Workspaces
- Key Vaults
- Managed Identities
- Private Endpoints
- Service Endpoints (from subnets)
- Diagnostic Settings
- Automation Accounts
- Tags and all resource metadata

**Note:** The exact set of resources may vary by landing zone implementation. The script will include whatever is found in your subscription.

This comprehensive inventory helps ensure your onboarding and Terraform workflows always reference the correct, pre-approved Azure resources, supporting compliance and reducing manual errors.

## Where Are the Discovered Values Stored?

All discovered resource information is saved to the `.env/azure_full_inventory.json` file in the project root. This JSON file contains resource IDs, names, tags, and metadata, and is used by onboarding and Terraform scripts to reference existing Azure resources. The file is excluded from version control for security.

---

## Reference in Documentation
- For details on how to use this JSON file in your Terraform and onboarding workflows, see the [BC Gov Azure Policy Terraform Notes](../../Resources/BcGovAzurePolicyTerraformNotes.md).
- Do **not** include secrets or resource IDs directly in documentation or markdown files. Always reference the protected JSON file.

## Folder Structure
```
OneTimeActivities/
└── GetAzureExistingResources/
    ├── unix/
    │   └── azure_full_inventory.sh
    ├── unix/
    │   └── PopulateTfvarsFromDiscoveredResources.sh
    └── windows/
        ├── azure_full_inventory.ps1
        └── PopulateTfvarsFromDiscoveredResources.ps1
```

---

**Note:**
- This workflow ensures your project always references the correct, pre-approved Azure resources, supporting compliance and reducing manual errors.
- If your landing zone changes or new resources are provisioned, simply re-run the script (on your platform) to update the JSON file.
- Both Bash and PowerShell automation scripts are supported and maintained. Use the appropriate script for your OS.

## After Running the Script: Update Your Terraform tfvars

1. **Extract the discovered resource values** (such as resource group name, VNet name, etc.) from `.env/azure_full_inventory.json`.
2. **Update your `terraform.tfvars` or environment variables** with these values so your Terraform code references the correct, pre-existing resources. Example:
   ```hcl
   resource_group_name    = "d5007d-dev-networking"
   virtual_network_name   = "d5007d-dev-vwan-spoke"
   # ...add other discovered values as needed
   ```
3. **Protect your tfvars file:**
   - Ensure your `terraform.tfvars` (or any file containing sensitive resource IDs) is listed in your `.gitignore` to prevent accidental commits.
   - Example `.gitignore` entry:
     ```
     terraform.tfvars
     *.auto.tfvars
     ```

> **Tip:** You can automate this step by running the provided Bash or PowerShell script (`PopulateTfvarsFromDiscoveredResources.sh` or `PopulateTfvarsFromDiscoveredResources.ps1`) to parse `.env/azure_full_inventory.json` and update your tfvars file or export environment variables for Terraform.
