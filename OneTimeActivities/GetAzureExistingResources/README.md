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

## After Running the Script: Update Your Terraform tfvars and Secrets Manually

After generating `.env/azure_full_inventory.json`, you must manually update your Terraform variable and secrets files using the provided templates. Automated population of these files is no longer supported.

1. **Manually update your Terraform variable files:**
   - Edit `terraform/terraform.tfvars` and `terraform/secrets.tfvars` in the project root.
   - Use the example and required variable names from `terraform/terraform.tfvars.template` and `terraform/secrets.tfvars.template`.
   - Copy values (such as resource group name, VNet name, etc.) from `.env/azure_full_inventory.json` into the appropriate fields in your tfvars files.

2. **Update environment-specific tfvars:**
   - Edit `terraform/environments/dev/terraform.tfvars` (and any other environment-specific tfvars files) as needed, using the same approach and referencing the templates for required variables.

3. **Update environment variables if used:**
   - If your workflow uses environment variables for Terraform, ensure these are set to match the discovered values in `.env/azure_full_inventory.json`.

4. **Protect your tfvars and secrets files:**
   - Ensure all tfvars and secrets files are listed in your `.gitignore` to prevent accidental commits.

> **Note:** The scripts `PopulateTfvarsFromDiscoveredResources.sh` and `PopulateTfvarsFromDiscoveredResources.ps1` have been deleted and are no longer supported. All tfvars and secrets population must be done manually using the templates and discovered inventory.
