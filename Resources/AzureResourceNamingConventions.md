# Azure Objects Naming Conventions

This document describes recommended naming conventions for all Azure resource types used in the BC Gov Azure Files PoC project. Consistent naming improves clarity, manageability, and compliance with BC Gov and Azure best practices.

## General Pattern

```
<prefix>-<project>-<env>-<optional-unique>
```

```markdown
# Azure Objects Naming Conventions

This document describes recommended naming conventions for all Azure resource types used in the BC Gov Azure Files PoC project. Consistent naming improves clarity, manageability, and compliance with BC Gov and Azure best practices.

## General Pattern

```

\<prefix\>-\<project\>-\<env\>-\<optional-unique\>

```

* **prefix**: Short abbreviation for the Azure resource type (see table below)

* **project**: Your project or team identifier (e.g., `<project-name>`)

* **env**: Environment (`dev`, `test`, `prod`, etc.)

* **optional-unique**: Optional numeric or descriptive suffix for uniqueness (e.g., `01`, `a`, `b`)

## Naming Conventions Table

| Azure Type | Prefix | Example Name | Notes/Constraints |
| ----- | ----- | ----- | ----- |
| Resource Group | rg | rg-<project-name>-dev |  |
| **Resource Group (TF State)** | **rg** | **rg-<project-name>-tfstate-dev** | **Dedicated RG for Terraform state; typically separate from application RGs.** |
| Storage Account | st | st<projectname>dev01 | Lowercase, no dashes, 3-24 chars, globally unique |
| **Storage Account (TF State)** | **st** | **st<projectname>tfstatedev01** | **Dedicated SA for Terraform state files. Lowercase, no dashes, 3-24 chars, globally unique.** |
| File Share | fs | fs-<project-name>-dev-01 | Lowercase, 3-63 chars, unique within storage account |
| Blob Container | sc | sc-<project-name>-dev-01 | Lowercase, 3-63 chars, unique within storage account |
| **Blob Container (TF State)** | **sc** | **sc-<project-name>-tfstate-dev** | **Dedicated container within the TF State Storage Account for Terraform state files (e.g., `dev.terraform.tfstate`).** |
| App Registration | app | app-<project-name> |  |
| Service Principal | sp | sp-<project-name> |  |
| Virtual Network | vnet | vnet-<project-name>-dev |  |
| Subnet | snet | snet-<project-name>-dev |  |
| Network Security Group | nsg | nsg-<project-name>-dev |  |
| Private Endpoint | pe | pe-<project-name>-dev |  |
| Private DNS Zone | pdns | pdns-<project-name>-dev |  |
| DNS Resolver | dnsr | dnsr-<project-name>-dev |  |
| Role Assignment | ra | ra-<project-name>-dev-storage | Not an Azure resource name, but use for documentation clarity |
| Managed Identity | mi | mi-<project-name>-dev |  |
| Log Analytics Workspace | law | law-<project-name>-dev |  |
| Key Vault | kv | kv-<project-name>-dev |  |
| Public IP | pip | pip-<project-name>-dev |  |
| Firewall | fw | fw-<project-name>-dev |  |
| Route Table | rt | rt-<project-name>-dev |  |
| Application Gateway | agw | agw-<project-name>-dev |  |

## Subnet Naming Convention

**Purpose:** Ensure subnets are clearly identified by project, environment, and function, and are easily discoverable in large environments.

**Format:**

```

subnet-\<project\>-\<env\>-\<function\>

```

* `subnet`: Literal prefix for all subnets.

* `<project>`: Short project or application code (e.g., `<project-code>`, `<project-name>`).

* `<env>`: Environment code (`dev`, `test`, `prod`, etc.).

* `<function>`: Purpose or usage of the subnet (e.g., `storage-pe`, `app`, `db`, `private-endpoints`).

**Examples:**

* `subnet-<project-code>-dev-storage-pe` (Storage Private Endpoint subnet for dev)

* `subnet-<project-name>-prod-app` (App subnet for production)

* `subnet-<app-name>-test-db` (Database subnet for test environment)

**Best Practices:**

* Use a dedicated subnet for each major function (e.g., app, db, private endpoints).

* For private endpoint subnets, use the suffix `-pe` or `-storage-pe` as appropriate.

* Use a `/28` address range for private endpoint subnets unless a larger range is required.

* Document all subnets and their purposes in your network design documentation.

## Multiple Instances Example

If you need multiple file shares, blob containers, or other resources, add a numeric or descriptive suffix:

* File Share: `fs-<project-name>-dev-01`, `fs-<project-name>-dev-02`

* Blob Container: `sc-<project-name>-dev-logs`, `sc-<project-name>-dev-backups`

## Additional Guidelines

* **Storage account names** must be globally unique, lowercase, and 3-24 characters, no dashes or special characters.

* **Resource group, vnet, subnet, etc.**: Use dashes for readability, keep under Azure’s length limits.

* **Environment**: Always include the environment for clarity and separation.

* **Role assignments**: Not a resource name, but use the convention in documentation and variable names.

* **App registrations/service principals**: Use the same pattern for clarity.

---

Adhering to these conventions will help ensure your Azure resources are easy to identify, manage, and audit across environments and teams.
