# Terraform Resources for Azure Files PoC Architecture

[https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
This document provides Terraform HCL (HashiCorp Configuration Language) examples for provisioning the Azure resources outlined in the Azure Files PoC Architecture Overview. These examples are designed to be a starting point and should be customized with your specific naming conventions, regions, and configurations.

> **Note:** For government-specific policies regarding User-Defined Routes (UDRs) and Azure File Sync, always consult with platform and security teams as mentioned in the architecture overview.

## Required Terraform Providers

The following Terraform providers are required to deploy these resources:

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0" # Use latest compatible version
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.9.0"  # Required for creating subnets with NSGs in BC Gov Azure Landing Zones
    }
  }
}

provider "azurerm" {
  features {}
  # Authentication is typically handled through Azure CLI or environment variables
  # Service principal authentication is only needed for CI/CD scenarios
}

provider "azapi" {
  # AzAPI provider typically uses the same authentication as AzureRM
}
```

## Preconditions

Before you can deploy these Terraform configurations, ensure you have the following prerequisites in place:

1. **Azure Subscription**: An active Azure subscription where you have permissions to create resources.

2. **Azure CLI**: Installed and configured on your local machine. You will use it to authenticate Terraform to your Azure subscription.
   - [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

3. **Terraform CLI**: Installed on your local machine.
   - [Install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

4. **Azure Credentials/Service Principal**: Terraform needs authenticated access to your Azure subscription. You can achieve this by:
   - **Azure CLI Login**: Running `az login` and logging in interactively. This is often sufficient for development and PoC environments.
   - **Service Principal**: For automated deployments (e.g., CI/CD pipelines), it's recommended to create an Azure Service Principal and configure Terraform with its credentials.
   - [Configure Terraform for Azure](https://learn.hashicorp.com/tutorials/terraform/azure-build)

5. **Permissions**: The Azure identity used by Terraform (your user account or Service Principal) must have sufficient permissions to create, update, and delete all the resources defined in these Terraform configurations (e.g., Contributor role at the subscription or resource group level).

6. **Git** (Optional but Recommended): For version control of your Terraform code, Git is highly recommended.

## Important Considerations for BC Government Azure Landing Zones

### Azure Policy and Subnet Creation

The BC Government Azure Landing Zones implement an Azure Policy that requires every subnet to have an associated Network Security Group (NSG) for security controls compliance. Standard Terraform resources don't support creating subnets with an associated NSG in a single step. 

For subnet creation, rather than using the standard `azurerm_subnet` resource, this sample uses the `azapi_resource` from the AzAPI Terraform Provider when creating subnets with NSGs. This approach accommodates the Azure Policy requirements.

### Private Endpoints and DNS Integration

When creating Private Endpoints, be aware that Azure Policy in the landing zones will automatically create DNS zone group associations. To avoid Terraform attempting to remove these associations on subsequent runs, all Private Endpoint resources include a `lifecycle` block with `ignore_changes` for the `private_dns_zone_group` property.

## 1. Azure Resource Group

A resource group is a logical container for Azure resources. All resources must reside in a resource group.

```terraform
resource "azurerm_resource_group" "rg_poc" {
  name     = "rg-azurefiles-poc"
  location = "canadacentral" # Customize your Azure region
}
```

## 2. Azure Virtual Network (VNet) - Hub and Spoke

We'll define two VNets: a Hub VNet for shared services (like Azure Firewall, gateways) and a Spoke VNet for the workload (e.g., Storage Account, VMs).

### Hub VNet

```terraform
resource "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub-poc"
  address_space       = ["10.100.0.0/16"] # Customize address space
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
}

# Note: Gateway subnet can use standard azurerm_subnet as it's exempt from NSG requirement
resource "azurerm_subnet" "subnet_gateway" {
  name                 = "GatewaySubnet" # This name is reserved for VPN/ExpressRoute Gateways
  resource_group_name  = azurerm_resource_group.rg_poc.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.100.0.0/27"] # Must be /27 or larger
}

# Note: Azure Firewall subnet can use standard azurerm_subnet as it's exempt from NSG requirement
resource "azurerm_subnet" "subnet_firewall" {
  name                 = "AzureFirewallSubnet" # This name is reserved for Azure Firewall
  resource_group_name  = azurerm_resource_group.rg_poc.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.100.1.0/26"] # Must be /26
}

resource "azurerm_subnet" "subnet_privatedns_resolver_inbound" {
  name                 = "PrivateDNSResolverInboundSubnet" # Dedicated subnet for Private DNS Resolver Inbound Endpoint
  resource_group_name  = azurerm_resource_group.rg_poc.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.100.2.0/28"]
  delegations {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      service_name = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "subnet_privatedns_resolver_outbound" {
  name                 = "PrivateDNSResolverOutboundSubnet" # Dedicated subnet for Private DNS Resolver Outbound Endpoint
  resource_group_name  = azurerm_resource_group.rg_poc.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.100.2.16/28"]
  delegations {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      service_name = "Microsoft.Network/dnsResolvers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# Example of a general-purpose subnet in Hub (e.g., for jumpbox, management tools)
resource "azurerm_subnet" "subnet_hub_general" {
  name                 = "snet-hub-general"
  resource_group_name  = azurerm_resource_group.rg_poc.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.100.10.0/24"]
}
```

### Spoke VNet
```terraform
resource "azurerm_virtual_network" "vnet_spoke" {
  name                = "vnet-spoke-poc"
  address_space       = ["10.200.0.0/16"] # Customize address space
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
}

# Subnet for Azure Files Private Endpoint (and potentially VMs accessing it)
# Using AzAPI provider to comply with BC Government Azure Policy requiring NSG association
# First, create the NSG that will be associated with the subnet
resource "azurerm_network_security_group" "nsg_storage_workload" {
  name                = "nsg-snet-storage-workload"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
}

# Then use AzAPI to create the subnet with NSG in a single step
resource "azapi_resource" "subnet_storage_workload" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = "snet-storage-workload"
  parent_id = azurerm_virtual_network.vnet_spoke.id
  
  # Prevent race conditions when creating/updating the VNet and subnet simultaneously
  locks = [
    azurerm_virtual_network.vnet_spoke.id
  ]

  body = jsonencode({
    properties = {
      addressPrefix = "10.200.0.0/24"
      privateEndpointNetworkPolicies = "Disabled"
      privateLinkServiceNetworkPolicies = "Enabled"
      networkSecurityGroup = {
        id = azurerm_network_security_group.nsg_storage_workload.id
      }
    }
  })

  response_export_values = ["*"]
}

# Subnet for Azure Virtual Machines (if separate from storage workload)
# Using AzAPI provider to comply with BC Government Azure Policy requiring NSG association
resource "azurerm_network_security_group" "nsg_vms" {
  name                = "nsg-snet-vms"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
}

resource "azapi_resource" "subnet_vms" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2023-04-01"
  name      = "snet-vms"
  parent_id = azurerm_virtual_network.vnet_spoke.id
  
  # Prevent race conditions when creating/updating the VNet and subnet simultaneously
  locks = [
    azurerm_virtual_network.vnet_spoke.id
  ]

  body = jsonencode({
    properties = {
      addressPrefix = "10.200.1.0/24"
      networkSecurityGroup = {
        id = azurerm_network_security_group.nsg_vms.id
      }
    }
  })

  response_export_values = ["*"]
}
```

### VNet Peering (Hub to Spoke)
```terraform
resource "azurerm_virtual_network_peering" "hub_to_spoke_peering" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = azurerm_resource_group.rg_poc.name
  virtual_network_name      = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_spoke.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
  allow_gateway_transit     = true # Allows Spoke to use Hub's gateway
}

resource "azurerm_virtual_network_peering" "spoke_to_hub_peering" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = azurerm_resource_group.rg_poc.name
  virtual_network_name      = azurerm_virtual_network.vnet_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
  use_remote_gateways       = true # Spoke uses Hub's gateway
}
```

## 3. Azure Storage Account

This is the central point for both file shares and blob containers.

```terraform
resource "azurerm_storage_account" "sa_files_poc" {
  name                     = "saazurefilespoc001" # Must be globally unique, lowercase, no special characters
  resource_group_name      = azurerm_resource_group.rg_poc.name
  location                 = azurerm_resource_group.rg_poc.location
  account_tier             = "Premium" # Options: Standard, Premium
  # For Premium File Shares, account_kind MUST be 'FileStorage' or 'StorageV2'
  # For Standard File Shares and Blobs, 'StorageV2' is general purpose.
  account_kind             = "FileStorage" # Change to "StorageV2" for Standard Files and Blobs
  account_replication_type = "LRS"       # Options: LRS, ZRS (for premium files), GRS, RAGRS, GZRS (for StorageV2)

  # Optional: Network ACLs for enhanced security (private endpoint will bypass this)
  network_acl {
    default_action = "Deny"
    # virtual_network_subnet_ids = [azurerm_subnet.subnet_storage_workload.id] # Allow access from specific subnet
    # ip_rules                   = ["YOUR_ON_PREM_PUBLIC_IP/32"] # Allow specific on-prem public IPs if no ExpressRoute/VPN
  }

  # Soft delete for file shares
  share_properties {
    retention_policy {
      enabled = true
      days    = 7 # Retain deleted shares for 7 days
    }
    # Enable SMB 3.1.1 protocol for maximum performance and security
    smb {
      versions = ["SMB3.1.1"]
    }
  }
}
```

## 4. Azure File Shares

Examples for both Premium and Standard file shares.

### Premium File Share (within a FileStorage kind Storage Account)
```terraform
resource "azurerm_storage_share" "fileshare_premium" {
  name                 = "fileshare-premium-media"
  storage_account_name = azurerm_storage_account.sa_files_poc.name
  quota                = 1000 # Size in GiB
  enabled_protocol     = "SMB" # Options: SMB, NFS
  # For Premium, the tier is implicitly Premium (set at Storage Account level)
}
```

### Standard File Share (if account_kind of storage account is StorageV2)

If using StorageV2 for the storage account, you can define access_tier for standard file shares.

```terraform
# Example if using azurerm_storage_account with account_kind = "StorageV2"
resource "azurerm_storage_share" "fileshare_standard" {
  name                 = "fileshare-standard-general"
  storage_account_name = azurerm_storage_account.sa_files_poc.name
  quota                = 500 # Size in GiB
  access_tier          = "Hot" # Options: Hot, Cool
  enabled_protocol     = "SMB"
}
```

## 5. Azure Blob Containers

A container within the storage account for tiering inactive files.

```terraform
resource "azurerm_storage_container" "blob_container_archive" {
  name                  = "blob-archive-media"
  storage_account_name  = azurerm_storage_account.sa_files_poc.name
  container_access_type = "private" # Options: private, blob, container
}
```

## 6. Blob Lifecycle Management Policy

Automates the movement of blobs between tiers (Hot, Cool, Archive).

```terraform
resource "azurerm_storage_management_policy" "blob_lifecycle_policy" {
  storage_account_id = azurerm_storage_account.sa_files_poc.id

  rule {
    name    = "move-inactive-to-cool"
    enabled = true
    filters {
      prefix_match        = ["${azurerm_storage_container.blob_container_archive.name}/"] # Apply to specific container
      blob_types          = ["blockBlob"]
      match_blob_index_tag = [] # Optional: filter by blob index tags
    }
    actions {
      base_blob {
        tier_to_cool_after_days_since_modification = 30    # Move to Cool after 30 days
        tier_to_archive_after_days_since_modification = 90 # Move to Archive after 90 days
        delete_after_days_since_modification          = 365 # Delete after 365 days
      }
    }
  }

  rule {
    name    = "delete-snapshots-after-7days"
    enabled = true
    filters {
      prefix_match = ["${azurerm_storage_container.blob_container_archive.name}/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      snapshot {
        delete_after_days_since_creation = 7 # Delete snapshots after 7 days
      }
    }
  }
}
```

## 7. Private Endpoint for Azure Files

Connects the storage account privately to your Spoke VNet.

```terraform
resource "azurerm_private_endpoint" "pe_azurefiles" {
  name                = "pe-azurefiles-poc"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
  subnet_id           = azapi_resource.subnet_storage_workload.id # Updated to reference the AzAPI-created subnet

  private_service_connection {
    name                           = "psc-azurefiles"
    private_connection_resource_id = azurerm_storage_account.sa_files_poc.id
    is_manual_connection           = false
    subresource_names              = ["file"] # Crucial for Azure Files
  }

  # Optional: Specify DNS Zone Group if using custom DNS integration
  # Note: BC Gov Landing Zone policies may automatically associate private endpoints with DNS zones
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.pdz_file.id]
  }
  
  # Prevent Terraform from removing the DNS Zone Group associations created by Azure Policy
  lifecycle {
    ignore_changes = [
      # Ignore changes to private_dns_zone_group as Azure Policy may update it automatically
      private_dns_zone_group,
    ]
  }
}
```

## 8. Private DNS Zone & Virtual Network Link

To resolve the private endpoint's FQDN (privatelink.file.core.windows.net) to its private IP.

```terraform
resource "azurerm_private_dns_zone" "pdz_file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.rg_poc.name
}

# Link Private DNS Zone to Spoke VNet
resource "azurerm_private_dns_zone_virtual_network_link" "pdz_file_link_spoke" {
  name                  = "pdz-link-spoke"
  resource_group_name   = azurerm_resource_group.rg_poc.name
  private_dns_zone_name = azurerm_private_dns_zone.pdz_file.name
  virtual_network_id    = azurerm_virtual_network.vnet_spoke.id
  registration_enabled  = false # Not needed for Private Endpoint resolution
}

# Link Private DNS Zone to Hub VNet (if DNS resolution needs to happen from Hub)
resource "azurerm_private_dns_zone_virtual_network_link" "pdz_file_link_hub" {
  name                  = "pdz-link-hub"
  resource_group_name   = azurerm_resource_group.rg_poc.name
  private_dns_zone_name = azurerm_private_dns_zone.pdz_file.name
  virtual_network_id    = azurerm_virtual_network.vnet_hub.id
  registration_enabled  = false
}
```

## 9. Azure DNS Private Resolver (Optional but Recommended for Hybrid DNS)

Facilitates DNS resolution between on-premises and Azure Private DNS zones without VM-based DNS servers.

```terraform
resource "azurerm_dns_resolver" "dns_resolver" {
  name                = "dns-resolver-poc"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  virtual_network_id  = azurerm_virtual_network.vnet_hub.id
}

resource "azurerm_dns_resolver_inbound_endpoint" "inbound_ep" {
  name                = "inbound-ep-poc"
  dns_resolver_id     = azurerm_dns_resolver.dns_resolver.id
  subnet_id           = azurerm_subnet.subnet_privatedns_resolver_inbound.id

  ip_configurations {
    private_ip_allocation_method = "Dynamic" # Or "Static" with a specific IP
  }
}

resource "azurerm_dns_resolver_outbound_endpoint" "outbound_ep" {
  name                = "outbound-ep-poc"
  dns_resolver_id     = azurerm_dns_resolver.dns_resolver.id
  subnet_id           = azurerm_subnet.subnet_privatedns_resolver_outbound.id
}
```terraform
resource "azurerm_dns_resolver_ruleset" "onprem_ruleset" {
  name                = "ruleset-onprem-domain"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  dns_resolver_outbound_endpoint_ids = [azurerm_dns_resolver_outbound_endpoint.outbound_ep.id]

  rule {
    name                = "onprem-domain-forward"
    pattern             = "yourdomain.local." # Customize your on-premises domain
    destination_ip_addresses = ["YOUR_ON_PREM_DNS_SERVER_IP"] # Customize on-prem DNS IP
    enabled             = true
    forwarding_enabled  = true
  }
}

resource "azurerm_dns_resolver_virtual_network_link" "spoke_ruleset_link" {
  name                  = "spoke-ruleset-link"
  dns_resolver_ruleset_id = azurerm_dns_resolver_ruleset.onprem_ruleset.id
  virtual_network_id    = azurerm_virtual_network.vnet_spoke.id
}
```

## 10. Network Security Groups (NSGs)

Apply NSGs to subnets to control traffic.

### NSG for Storage Workload Subnet
```terraform
resource "azurerm_network_security_group" "nsg_storage_workload" {
  name                = "nsg-snet-storage-workload"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
}

# Note: The NSG association is now handled within the azapi_resource for the subnet
# No separate azurerm_subnet_network_security_group_association needed

resource "azurerm_network_security_rule" "allow_smb" {
  name                        = "AllowSMBFromHubAndOnPrem"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "445"
  source_address_prefixes     = [
    azurerm_virtual_network.vnet_hub.address_space[0], # Hub VNet CIDR
    "YOUR_ON_PREM_IP_RANGE" # Customize your on-premises IP range
  ]
  destination_address_prefix  = azurerm_virtual_network.vnet_spoke.address_space[0] # Spoke VNet CIDR
  resource_group_name         = azurerm_resource_group.rg_poc.name
  network_security_group_name = azurerm_network_security_group.nsg_storage_workload.name
}

resource "azurerm_network_security_rule" "allow_private_endpoint_access" {
  name                        = "AllowPrivateEndpointAccess"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = azurerm_virtual_network.vnet_spoke.address_space[0] # From within Spoke VNet
  destination_address_prefix  = jsondecode(azapi_resource.subnet_storage_workload.body).properties.addressPrefix # To the Private Endpoint Subnet
  resource_group_name         = azurerm_resource_group.rg_poc.name
  network_security_group_name = azurerm_network_security_group.nsg_storage_workload.name
}
```

## 11. Azure Firewall

```terraform
resource "azurerm_public_ip" "pip_firewall" {
  name                = "pip-firewall-poc"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "az_firewall" {
  name                = "azfw-poc"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet_firewall.id
    public_ip_address_id = azurerm_public_ip.pip_firewall.id
  }
}

resource "azurerm_firewall_network_rule_collection" "fw_network_rules" {
  name                = "InternalTrafficRules"
  azure_firewall_name = azurerm_firewall.az_firewall.name
  resource_group_name = azurerm_resource_group.rg_poc.name
  priority            = 100
  action              = "Allow"

  rule {
    name                  = "Allow_Hub_Spoke_Communication"
    source_addresses      = [azurerm_virtual_network.vnet_hub.address_space[0], azurerm_virtual_network.vnet_spoke.address_space[0]]
    destination_addresses = [azurerm_virtual_network.vnet_hub.address_space[0], azurerm_virtual_network.vnet_spoke.address_space[0]]
    destination_ports     = ["*"]
    protocols             = ["Any"]
  }

  rule {
    name                  = "Allow_OnPrem_to_Spoke_SMB"
    source_addresses      = ["YOUR_ON_PREM_IP_RANGE"]
    destination_addresses = [jsondecode(azapi_resource.subnet_storage_workload.body).properties.addressPrefix]
    destination_ports     = ["445"]
    protocols             = ["TCP"]
  }
}

resource "azurerm_firewall_application_rule_collection" "fw_app_rules" {
  name                = "InternetAccessRules"
  azure_firewall_name = azurerm_firewall.az_firewall.name
  resource_group_name = azurerm_resource_group.rg_poc.name
  priority            = 200
  action              = "Allow"

  rule {
    name                = "Allow_Google_Access"
    source_addresses    = [azurerm_virtual_network.vnet_spoke.address_space[0]]
    target_fqdns        = ["www.google.com"]
    protocols {
      port = 80
      type = "Http"
    }
    protocols {
      port = 443
      type = "Https"
    }
  }
}

resource "azurerm_route_table" "spoke_route_table" {
  name                = "rt-spoke-traffic"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
  disable_bgp_route_propagation = true
}

resource "azurerm_subnet_route_table_association" "spoke_subnet_route_table_association" {
  subnet_id      = azapi_resource.subnet_storage_workload.id
  route_table_id = azurerm_route_table.spoke_route_table.id
}

resource "azurerm_route" "default_to_firewall" {
  name                   = "DefaultRouteToFirewall"
  resource_group_name    = azurerm_resource_group.rg_poc.name
  route_table_name       = azurerm_route_table.spoke_route_table.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.az_firewall.ip_configuration[0].private_ip_address
}
```

## 12. Azure Virtual Network Gateway (for VPN/ExpressRoute)
Example for an ExpressRoute Gateway. A VPN Gateway would be similar.

```terraform
resource "azurerm_public_ip" "pip_vnet_gateway" {
  name                = "pip-vnet-gateway-poc"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
  allocation_method   = "Dynamic"
}

resource "azurerm_virtual_network_gateway" "vnet_gateway" {
  name                = "vnet-gateway-poc"
  location            = azurerm_resource_group.rg_poc.location
  resource_group_name = azurerm_resource_group.rg_poc.name
  type                = "ExpressRoute"
  vpn_type            = "RouteBased"
  sku                 = "Standard"

  ip_configuration {
    name                          = "vnetGatewayIpConfig"
    public_ip_address_id          = azurerm_public_ip.pip_vnet_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet_gateway.id
  }
}
```

### Example ExpressRoute Connection (requires an existing ExpressRoute circuit)

```terraform
/*
resource "azurerm_network_connection" "er_connection" {
  name                           = "er-connection-poc"
  resource_group_name            = azurerm_resource_group.rg_poc.name
  location                       = azurerm_resource_group.rg_poc.location
  connection_type                = "ExpressRoute"
  virtual_network_gateway_id     = azurerm_virtual_network_gateway.vnet_gateway.id
  express_route_circuit_peering_id = "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_ER_RG/providers/Microsoft.Network/expressRouteCircuits/YOUR_ER_CIRCUIT_NAME/peerings/AzurePrivatePeering"
}
*/


### Example VPN Connection
```terraform
/*
resource "azurerm_vpn_connection" "vpn_connection" {
  name                            = "vpn-connection-poc"
  resource_group_name             = azurerm_resource_group.rg_poc.name
  virtual_network_gateway_id      = azurerm_virtual_network_gateway.vnet_gateway.id
  remote_virtual_network_gateway_id = azurerm_local_network_gateway.onprem_lgw.id
  shared_key                      = "YOUR_SHARED_KEY"
}

resource "azurerm_local_network_gateway" "onprem_lgw" {
  name                = "lgw-onprem-poc"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  gateway_ip_address  = "YOUR_ON_PREM_VPN_DEVICE_PUBLIC_IP"
  address_space       = ["YOUR_ON_PREM_IP_RANGE"]
}
*/
```

## 13. Azure File Sync (Optional)
Resources for setting up Azure File Sync.

```terraform
resource "azurerm_storage_sync_service" "afs_service" {
  name                = "afs-syncservice-poc"
  resource_group_name = azurerm_resource_group.rg_poc.name
  location            = azurerm_resource_group.rg_poc.location
  incoming_traffic_policy = "AllowAll"
}

resource "azurerm_storage_sync_group" "afs_sync_group" {
  name                = "afs-syncgroup-media"
  storage_sync_service_id = azurerm_storage_sync_service.afs_service.id
}

resource "azurerm_storage_sync_cloud_endpoint" "afs_cloud_endpoint" {
  name                = "afs-cloudendpoint-media"
  storage_sync_group_id = azurerm_storage_sync_group.afs_sync_group.id
  file_share_name     = azurerm_storage_share.fileshare_premium.name
  storage_account_id  = azurerm_storage_account.sa_files_poc.id
}

# Note: The on-premises 'server endpoint' (where the Azure File Sync agent is installed)
# is configured after the cloud resources are provisioned. This typically involves
# installing the agent on an on-premises Windows Server and registering it, then
# creating the server endpoint in the sync group via Azure portal or PowerShell.
# Terraform cannot directly manage the installation of the agent on an on-premises server.

```

## CI/CD Integration for Terraform Deployment

This section provides guidance on implementing CI/CD for Terraform in the BC Government Azure environment.

### Authentication Options

#### 1. GitHub Actions with OpenID Connect (OIDC)

For GitHub Actions, use OIDC authentication instead of long-lived service principal credentials:

```yaml
# Example GitHub workflow snippet for Terraform with OIDC
name: 'Terraform Deploy'

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

permissions:
  id-token: write # Required for OIDC
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      
    - name: Terraform Init
      run: terraform init
      
    - name: Terraform Plan
      run: terraform plan -out=tfplan
      
    - name: Terraform Apply
      if: github.event_name == 'push'
      run: terraform apply -auto-approve tfplan
```

#### 2. Self-Hosted GitHub Runners

For accessing resources not available to public runners (like private storage or databases), BC Government provides an Azure Verified Module for self-hosted runners. Reference the sample implementation at the [Azure Landing Zone Samples repository](https://github.com/bcgov/azure-lz-samples/tree/main/tools/cicd_self_hosted_agents/).

#### 3. Azure DevOps with Managed DevOps Pools

If using Azure DevOps, leverage Managed DevOps Pools through the sample implementation available in the [Azure Landing Zone Samples repository](https://github.com/bcgov/azure-lz-samples/tree/main/tools/cicd_managed_devops_pools/).

### Best Practices for Terraform in CI/CD

1. **Environment Separation**: Use different variable files for different environments (dev, test, prod)

2. **Tag Management**: Always use `lifecycle` blocks with `ignore_changes` for tags that might be modified by Azure policies:
   ```terraform
   lifecycle {
     ignore_changes = [
       tags["CreatedBy"],
       tags["CreatedOn"]
     ]
   }
   ```

3. **State Management**: Use remote state storage in Azure Storage Account with state locking enabled:
   ```terraform
   terraform {
     backend "azurerm" {
       resource_group_name   = "rg-terraform-state"
       storage_account_name  = "sterraformstatepoc"
       container_name        = "tfstate"
       key                   = "azurefiles.terraform.tfstate"
     }
   }
   ```

4. **Cross-Subscription Deployment**: If deploying runners in a different subscription than resources, ensure firewall rules are configured to allow cross-subscription access.

5. **Secure Variables**: Never store sensitive variables in version control. Use GitHub Secrets, Azure KeyVault, or Azure DevOps variable groups.

- **Landing Zone Samples Reference:** See [BCGov-AzureLandingZoneSamplesSummary.md](BCGov-AzureLandingZoneSamplesSummary.md) for a summary of the official BC Gov Azure Landing Zone sample modules, best practices, and recommendations for future enhancements and alignment.