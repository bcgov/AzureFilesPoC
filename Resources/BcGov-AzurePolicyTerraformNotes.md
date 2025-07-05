# BC Gov Azure Landing Zone Policy Compliance with Terraform

> **Source:** [BC Gov Azure IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)

This document summarizes key Azure Policy compliance requirements and Terraform workarounds for BC Gov Azure Landing Zones, including public IP restrictions and subnet/NSG requirements.

## 1. Public IP Address Policy for PaaS Resources

BC Gov Azure Landing Zones enforce a policy that **denies creation of PaaS resources (such as Storage Accounts) with public network access enabled**. To comply:

- Always set `public_network_access_enabled = false` in your Terraform resource blocks for Storage Accounts and other PaaS resources.
- In some environments, you must also add a `network_rules` block to explicitly deny public access and allow only private subnets:

```hcl
resource "azurerm_storage_account" "example" {
  # ...existing code...
  public_network_access_enabled = false
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.example.id] # Replace with your subnet resource
  }
  # ...existing code...
}
```

If you do not specify a subnet, the storage account will be inaccessible—even from private networks.

## 2. Subnet Creation with NSG Requirement

Azure Policy requires every subnet to have an associated Network Security Group (NSG). Terraform's `azurerm_subnet` cannot create a subnet and associate an NSG in a single step. Use the AzAPI provider:

```hcl
resource "azapi_resource" "subnet" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = "SubnetName"
  parent_id = data.azurerm_virtual_network.vnet.id
  locks     = [data.azurerm_virtual_network.vnet.id]
  body = jsonencode({
    properties = {
      addressPrefix = "10.0.1.0/24"
      networkSecurityGroup = {
        id = azurerm_network_security_group.nsg.id
      }
    }
  })
  response_export_values = ["*"]
}
```

## 3. Private Endpoint and DNS Policy

Azure Policy may automatically associate Private Endpoints with Private DNS Zones. To prevent Terraform from trying to remove these policy-created associations, add a lifecycle block:

```hcl
resource "azurerm_private_endpoint" "example" {
  # ...existing code...
  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}
```

## 4. AzAPI Provider Limitations

When deleting an `azapi_update_resource`, no operation is performed and properties may remain unchanged. Always restore properties before deleting if you want to revert changes.

## 5. Recommended Resource Creation Sequence (Best Practice)

When building Azure infrastructure with Terraform in BC Gov Landing Zones, follow this sequence to maximize policy compliance and avoid deployment errors:

1. **Resource Group**
   - Create the resource group first. All resources must be placed inside a resource group.
2. **Networking (VNet, Subnets, NSGs)**
   - Create the Virtual Network (VNet).
   - Create Network Security Groups (NSGs).
   - Create subnets, associating each with an NSG (use AzAPI if required by policy).
   - (Optional) Create route tables and associate them with subnets.
3. **Private Endpoints and Private IPs**
   - If required, create private endpoints and/or private IPs for PaaS resources.
   - Ensure subnets for private endpoints exist before creating the endpoint.
4. **PaaS Resources (e.g., Storage Accounts, Databases)**
   - Create storage accounts and other PaaS resources with `public_network_access_enabled = false`.
   - Add `network_rules` to restrict access to only required subnets.
5. **Containers, File Shares, Blobs**
   - Once the storage account exists, create blob containers, file shares, or other child resources. 
   - **Update (July 2025): File share creation is now fully automated and unblocked in both local and CI/CD environments.**
6. **Private DNS Zones and Links**
   - If using private endpoints, create private DNS zones and link them to the appropriate VNets.
7. **Other Dependent Resources**
   - Create VMs, app services, or other resources that depend on the above infrastructure.

**Key Points:**
- Always create parent resources before children (e.g., resource group → VNet → subnet → storage account → blob).
- For BC Gov, ensure all networking and security policies are satisfied before creating PaaS resources.
- Use `lifecycle` and `ignore_changes` blocks as needed to handle Azure Policy automation (especially for private endpoints and DNS).

## 6. Using Pre-Provisioned Networking in BC Gov Landing Zones

In BC Gov Azure Landing Zones, your subscription may be pre-provisioned with a hub-and-spoke VNet architecture and associated network resources (such as NSGs and subnets). **Best practice is to use these existing resources rather than creating new VNets or subnets.**

For example, you may see a pre-provisioned spoke VNet like: 
- **Name:** see .env/azure-credentials.json
- **Resource Group:** 
- **Location:** 
- **Address space:** 
- **DNS servers:** 
- **Virtual network ID:** 

**How to use these resources in Terraform:**
- Use `data` blocks (e.g., `data.azurerm_virtual_network`, `data.azurerm_subnet`, `data.azurerm_network_security_group`) to reference existing VNets, subnets, and NSGs.
- Do not attempt to create new VNets or subnets unless explicitly required and approved.
- When creating PaaS resources (e.g., storage accounts), reference the existing subnet(s) in your `network_rules` or private endpoint configuration.

**Example:**
```hcl
data "azurerm_virtual_network" "spoke" {
  name                = "<vnet-name>"
  resource_group_name = "<networking-resource-group-name>"
}

data "azurerm_subnet" "workload" {
  name                 = "<workload-subnet-name>"
  virtual_network_name = data.azurerm_virtual_network.spoke.name
  resource_group_name  = data.azurerm_virtual_network.spoke.resource_group_name
}

resource "azurerm_storage_account" "example" {
  # ...existing code...
  public_network_access_enabled = false
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [data.azurerm_subnet.workload.id]
  }
  # ...existing code...
}
```

**Tip:**
- Always check with your platform team or documentation to confirm which resources are pre-provisioned and how you should reference them.
- This approach ensures compliance and avoids conflicts with landing zone policies.

---

**Note:**
- Do not include secrets or resource IDs directly in documentation. Always reference the protected `.env/azure_full_inventory.json` file, which is generated and updated by the script in `OneTimeActivities/GetAzureExistingResources/unix/azure_full_inventory.sh`. See that folder's README for details.

For more details and updates, see the [BC Gov Azure IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/).
