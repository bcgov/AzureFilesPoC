# Azure Objects Naming Conventions

This document describes recommended naming conventions for all Azure resource types used in the BC Gov Azure Files PoC project. Consistent naming improves clarity, manageability, and compliance with BC Gov and Azure best practices.

## General Pattern

```
<prefix>-<project>-<env>-<optional-unique>
```
- **prefix**: Short abbreviation for the Azure resource type (see table below)
- **project**: Your project or team identifier (e.g., `ag-pssg-azure-poc`)
- **env**: Environment (`dev`, `test`, `prod`, etc.)
- **optional-unique**: Optional numeric or descriptive suffix for uniqueness (e.g., `01`, `a`, `b`)

## Naming Conventions Table

| Azure Type                | Prefix   | Example Name                        | Notes/Constraints                                              |
|--------------------------|----------|-------------------------------------|---------------------------------------------------------------|
| Resource Group           | rg       | rg-ag-pssg-azure-poc-dev            |                                                               |
| Storage Account          | st       | stagpssgazurepocdev01               | Lowercase, no dashes, 3-24 chars, globally unique             |
| File Share               | fs       | fs-ag-pssg-azure-poc-dev-01         | Lowercase, 3-63 chars, unique within storage account           |
| Blob Container           | sc       | sc-ag-pssg-azure-poc-dev-01         | Lowercase, 3-63 chars, unique within storage account           |
| App Registration         | app      | app-ag-pssg-azure-poc               |                                                               |
| Service Principal        | sp       | sp-ag-pssg-azure-poc                |                                                               |
| Virtual Network          | vnet     | vnet-ag-pssg-azure-poc-dev          |                                                               |
| Subnet                   | snet     | snet-ag-pssg-azure-poc-dev          |                                                               |
| Network Security Group   | nsg      | nsg-ag-pssg-azure-poc-dev           |                                                               |
| Private Endpoint         | pe       | pe-ag-pssg-azure-poc-dev            |                                                               |
| Private DNS Zone         | pdns     | pdns-ag-pssg-azure-poc-dev          |                                                               |
| DNS Resolver             | dnsr     | dnsr-ag-pssg-azure-poc-dev          |                                                               |
| Role Assignment          | ra       | ra-ag-pssg-azure-poc-dev-storage    | Not an Azure resource name, but use for documentation clarity  |
| Managed Identity         | mi       | mi-ag-pssg-azure-poc-dev            |                                                               |
| Log Analytics Workspace  | law      | law-ag-pssg-azure-poc-dev           |                                                               |
| Key Vault                | kv       | kv-ag-pssg-azure-poc-dev            |                                                               |
| Public IP                | pip      | pip-ag-pssg-azure-poc-dev           |                                                               |
| Firewall                 | fw       | fw-ag-pssg-azure-poc-dev            |                                                               |
| Route Table              | rt       | rt-ag-pssg-azure-poc-dev            |                                                               |
| Application Gateway      | agw      | agw-ag-pssg-azure-poc-dev           |                                                               |

## Subnet Naming Convention
**Purpose:** Ensure subnets are clearly identified by project, environment, and function, and are easily discoverable in large environments.

**Format:**
```
subnet-<project>-<env>-<function>
```
- `subnet`: Literal prefix for all subnets.
- `<project>`: Short project or application code (e.g., `d5007d`, `ag-pssg-azure-poc`).
- `<env>`: Environment code (`dev`, `test`, `prod`, etc.).
- `<function>`: Purpose or usage of the subnet (e.g., `storage-pe`, `app`, `db`, `private-endpoints`).

**Examples:**
- `subnet-d5007d-dev-storage-pe` (Storage Private Endpoint subnet for dev)
- `subnet-ag-pssg-azure-poc-prod-app` (App subnet for production)
- `subnet-hrms-test-db` (Database subnet for HRMS test environment)

**Best Practices:**
- Use a dedicated subnet for each major function (e.g., app, db, private endpoints).
- For private endpoint subnets, use the suffix `-pe` or `-storage-pe` as appropriate.
- Use a `/28` address range for private endpoint subnets unless a larger range is required.
- Document all subnets and their purposes in your network design documentation.

## Multiple Instances Example

If you need multiple file shares, blob containers, or other resources, add a numeric or descriptive suffix:
- File Share: `fs-ag-pssg-azure-poc-dev-01`, `fs-ag-pssg-azure-poc-dev-02`
- Blob Container: `sc-ag-pssg-azure-poc-dev-logs`, `sc-ag-pssg-azure-poc-dev-backups`

## Additional Guidelines
- **Storage account names** must be globally unique, lowercase, and 3-24 characters, no dashes or special characters.
- **Resource group, vnet, subnet, etc.**: Use dashes for readability, keep under Azure’s length limits.
- **Environment**: Always include the environment for clarity and separation.
- **Role assignments**: Not a resource name, but use the convention in documentation and variable names.
- **App registrations/service principals**: Use the same pattern for clarity.

## References
- [Microsoft Azure Naming Rules and Restrictions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)
- [BC Gov Cloud Naming Standards](https://github.com/bcgov/cloud-pathfinder-documentation/blob/main/docs/AzureNamingConventions.md)

---

Adhering to these conventions will help ensure your Azure resources are easy to identify, manage, and audit across environments and teams.
