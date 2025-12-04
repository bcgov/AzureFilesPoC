# Azure RBAC Role Assignment Scripts

This directory contains scripts for setting up Azure Role-Based Access Control (RBAC) permissions for the Azure Files PoC project.

## Quick Setup Guide

### Prerequisites
1. Azure CLI installed and authenticated (`az login`)
2. Resource groups created (run `step6_create_resource_group.sh` first)
3. Custom roles created (run `step6.1_CreateCustomRole.sh` first)
4. GitHub Actions service principal created with known object ID

### Complete Role Assignment Setup

To set up ALL required role assignments for the GitHub Actions service principal from scratch, run these commands in order:

```bash
# 1. Main DEV Resource Group (Storage & Core Resources)
bash step6.2_assign_roles_to_resource_group.sh \
  --rgname "rg-<project-name>-<environment>" \
  --assignee "<service-principal-object-id>" \
  --role "Storage Account Contributor" \
  --role "[<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer"

# 2. CI/CD Tools Resource Group (VMs, Managed Identity, Networking)
bash step6.2_assign_roles_to_resource_group.sh \
  --rgname "rg-<project-name>-<environment>-tools" \
  --assignee "<service-principal-object-id>" \
  --role "Managed Identity Operator" \
  --role "Network Contributor" \
  --role "Virtual Machine Contributor" \
  --role "[<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer"

# 3. BC Gov Networking Resource Group (Subnet Creation & Management)
bash step6.2_assign_roles_to_resource_group.sh \
  --rgname "<ministry-code>-<environment>-networking" \
  --assignee "<service-principal-object-id>" \
  --role "Network Contributor" \
  --role "[<team-name>-<project-name>-MANAGED]-<environment>-role-assignment-writer"
```

### Verification

After running the setup commands, verify all role assignments:

```bash
# View all role assignments for the service principal
az role assignment list --assignee "<service-principal-object-id>" --all --output table

# Check subscription-level roles (assigned separately)
az role assignment list --assignee "<service-principal-object-id>" --scope "/subscriptions/$(az account show --query id -o tsv)" --output table
```

## Key Files

- **`step6.2_assign_roles_to_resource_group.sh`** - Main role assignment script with comprehensive documentation
- **`<team-name>-<project-name>-MANAGED-<environment>-resource-group-contributor.json`** - Custom role definition for resource group management
- **`<team-name>-<project-name>-MANAGED-<environment>-role-assignment-writer.json`** - Custom role definition for role assignment management

## Role Assignment Summary

### Resource Group Level
- **rg-<project-name>-<environment>**: Storage Account Contributor, Custom Role Assignment Writer
- **rg-<project-name>-<environment>-tools**: Managed Identity Operator, Network Contributor, VM Contributor, Custom Role Assignment Writer  
- **<ministry-code>-<environment>-networking**: Network Contributor, Custom Role Assignment Writer
- **rg-<project-name>-tfstate-<environment>**: No direct assignments (inherits from subscription)

### Subscription Level
These are assigned by `step2_grant_subscription_level_permissions.sh`:
- Reader
- Storage Account Contributor
- Monitoring Contributor
- [BCGOV-MANAGED-LZ-LIVE] Network-Subnet-Contributor
- Private DNS Zone Contributor

## Troubleshooting

If you encounter "authorization failed" errors during Terraform deployment:

1. Verify all resource groups exist: `az group list --output table`
2. Verify all custom roles exist: `az role definition list --custom-role-only --output table`
3. Re-run the role assignment commands above
4. Check subscription-level roles are assigned
5. Validate with: `az role assignment list --assignee "<service-principal-object-id>" --all`

## Script Features

The `step6.2_assign_roles_to_resource_group.sh` script includes:
- ✅ Before/after role assignment verification
- ✅ Comprehensive error handling  
- ✅ Inventory tracking in JSON format
- ✅ Support for multiple roles per execution
- ✅ Detailed logging and status reporting
- ✅ Complete setup documentation in comments
