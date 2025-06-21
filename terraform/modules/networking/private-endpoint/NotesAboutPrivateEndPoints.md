# Using Terraform to Create Private Endpoints

**Source:** [BC Gov IaC & CI/CD Best Practices – Using Terraform to Create Private Endpoints](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/#using-terraform-to-create-private-endpoints)

**See also:**
- `.env/azure_full_inventory.json`
- `/terraform/terraform.tfvars`

---

When using Terraform to create Azure infrastructure—especially **Private Endpoints**—within your assigned Virtual Network, please be aware of the following challenge:

> **Important:**
> After a Private Endpoint is created, Azure Policy automation within the Landing Zones will automatically associate the Private Endpoint with the appropriate Private DNS Zone and create the necessary DNS records.
> 
> **However,** the next time you run `terraform plan` or `terraform apply`, Terraform will detect that this change has occurred outside of your code and will attempt to remove the association between the Private Endpoint and the Private DNS Zone. This can break DNS resolution for your resources via the Private Endpoint.

**Example Terraform plan output:**

```terraform
  ~ resource "azurerm_private_endpoint" "this" {
        id   = "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/caf-ghr/providers/Microsoft.Network/privateEndpoints/pe-acrghr"
        name = "pe-acrghr"

      - private_dns_zone_group {
          - id                   = "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/caf-ghr/providers/Microsoft.Network/privateEndpoints/pe-acrghr/privateDnsZoneGroups/deployedByPolicy" -> null
          - name                 = "deployedByPolicy" -> null
          - private_dns_zone_ids = [
              - "/subscriptions/xxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/bcgov-managed-lz-forge-dns/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io",
            ] -> null
        }
    }
```

While Azure Policy should automatically re-associate the Private Endpoint with the Private DNS Zone, **it is strongly recommended to add a `lifecycle` block with `ignore_changes` for the `private_dns_zone_group` property** in your Terraform code. This ensures Terraform ignores changes made by Azure Policy and prevents accidental removal of DNS associations.

---

> **ALWAYS INCLUDE THIS BLOCK IN YOUR PRIVATE ENDPOINT RESOURCES:**

```terraform
resource "azurerm_private_endpoint" "example" {
  name                = "example-endpoint"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  subnet_id           = azurerm_subnet.example.id

  private_service_connection {
    name                           = "example-privateserviceconnection"
    private_connection_resource_id = azurerm_storage_account.example.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to private_dns_zone_group, as Azure Policy may update it automatically.
      private_dns_zone_group,
    ]
  }
}
```

---

# Example: Private Endpoint Resource with Variables and Local State

# This example assumes you are using variables for resource names and IDs, as defined in your tfvars files.
# The Terraform state is managed locally in `terraform/validation/terraform.tfstate`.

```terraform
# Variable declarations (typically in variables.tf):
# variable "resource_group" { type = string }
# variable "location" { type = string }
# variable "subnet_id" { type = string }
# variable "storage_account_id" { type = string }

resource "azurerm_private_endpoint" "example" {
  name                = local.pe_name
        # Use a name that follows your AzureObjectsNamingConventions.md, e.g.:
        # local.pe_name = "ag-pssg-azure-poc-pe-dev-01"
        # Construct this using locals and variables for project prefix, resource type, environment, and sequence.
  location            = var.location
  resource_group_name = var.resource_group
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = local.pe_connection_name
    # Use a name that follows your AzureObjectsNamingConventions.md, e.g.:
    # local.pe_connection_name = "ag-pssg-azure-poc-pe-conn-dev-01"
    # Construct this using locals and variables for project prefix, resource type, environment, and sequence.
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to private_dns_zone_group, as Azure Policy may update it automatically.
      private_dns_zone_group,
    ]
  }
}
```

# Be sure to provide values for these variables in your terraform.tfvars file or via environment discovery scripts.
# The local state file (terraform/validation/terraform.tfstate) will track resource state for this module.

---

**Reminder:**
- When building Terraform scripts for private networking in BC Gov Azure, always include the `lifecycle { ignore_changes = [private_dns_zone_group] }` block in your `azurerm_private_endpoint` resources.
- This prevents Terraform from trying to remove DNS zone associations created by Azure Policy automation.