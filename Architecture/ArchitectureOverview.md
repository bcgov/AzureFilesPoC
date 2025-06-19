# Azure Files PoC Architecture Overview

## Overview

This architecture supports the evaluation of Azure Files with optional integration to Azure Blob Storage. It is designed to ensure secure, performant, and compliant access to large media files (e.g., video/audio) from both on-premises and cloud environments.

### Hub-and-Spoke Architecture Alignment

This design aligns with the BC Government's implementation of the Cloud Adoption Framework (CAF) hub-and-spoke network topology. In this model:

- The **hub** is the central point of connectivity to the on-premises network
- The **spoke** is the virtual network (VNET) that connects to the hub, containing workload-specific resources
- This model centralizes shared services in the hub while providing isolation for workloads in the spokes

The BC Government has implemented this using the modern Virtual WAN (vWAN) architecture, where each Project Set is provisioned with a spoke Virtual Network (VNet) that connects to the Virtual Hub (vHub). 

In our PoC architecture:
- The spoke VNet contains the Azure Files shares, Blob Storage, and other related Azure resources
- These resources connect to on-premises environments through the hub's connectivity services
- Private endpoints in the spoke provide secure access to storage resources
- Network security groups and other controls can be applied at the spoke level

For more details on the BC Government's Azure landing zone architecture, see the [BC Government's Azure Landing Zone Overview](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/bc-govs-azure-landing-zone-overview/#monitoring-and-logging).

## Architecture Diagram


![azure files express route drawio](https://github.com/user-attachments/assets/403dafc8-8523-4eb2-b8a2-3e9b91a4f8ab)


This diagram illustrates the hybrid connectivity model using VPN and ExpressRoute, with Azure Files accessed via Private Endpoint and optional integration with Azure Blob Storage for tiering.

## Components

### Core Storage & Access

| **Component** | **Description** |
|---------------|-----------------|
| Azure Files (Premium Tier) | For high-performance SMB file shares (e.g., real-time playback, active evidence access). |
| Azure Files (Standard Tier) | For general-purpose SMB shares with lower cost; supports manual tiering to Cool. |
| Azure Storage Account | The foundational Azure service that **hosts** Azure Files shares and optionally Blob Storage containers. All Azure Files shares are deployed within a Storage Account. For this PoC, `StorageV2` (general-purpose v2) or `FileStorage` (for Premium) `account_kind` will be configured. |
| Azure Blob Storage (Hot/Cool/Archive) | Used for storing large, infrequently accessed **block blobs** with lifecycle-based tiering. When files are moved from Azure Files to Blob Storage for cost optimization, they become block blobs. |
| Azure File Sync | Synchronizes file shares between on-premises Windows Servers and Azure File Shares, enabling distributed access and caching. **Note:** For a hybrid approach to Azure File Sync that aims to reduce traffic on the ExpressRoute Circuit for less sensitive file shares, **consultation with an OCIO security architect** will be required. |

### Networking & Connectivity

| **Component** | **Description** |
|---------------|-----------------|
| **On-premises Network & DNS** | Represents the on-premises infrastructure, including users, existing file shares, and local DNS servers (`dns.ca` in the diagram) responsible for resolving on-premises resources and conditionally forwarding Azure-specific queries. |
| VPN Gateway | Enables secure access from on-premises to Azure over VPN (short-term, typically for initial setup or smaller deployments). |
| ExpressRoute Circuit | Private, high-performance, and low-latency connection from on-premises to Azure (long-term, for production-grade hybrid connectivity). |
| ExpressRoute Gateway | Azure-side gateway for ExpressRoute circuit connectivity, allowing the VNet to connect to the on-premises network. |
| **Azure Virtual Network (VNet) - Hub** | The central VNet in a Hub-Spoke topology, hosting shared services like Azure Firewall, VPN/ExpressRoute Gateways, and centralized DNS resolvers. |
| **Azure Virtual Network (VNet) - Spoke** | A VNet peered with the Hub VNet, dedicated to hosting workload-specific resources, including Azure Storage Accounts, Azure Files shares, and Virtual Machines. |
| Private Endpoint for Azure Files | Maps a private IP address from your Azure VNet (specifically the Spoke VNet) to the Azure Storage account, ensuring secure and private access to Azure Files over the Azure backbone. |
| Private DNS Zone | Resolves private endpoint names (e.g., `privatelink.file.core.windows.net`) to their corresponding private IP addresses. It includes components like: <br> - **Inbound Endpoints:** Allow DNS queries from on-premises or other VNets to ingress to the Azure DNS Private Resolver. <br> - **Outbound Endpoints:** Allow DNS queries from Azure to egress to on-premises DNS servers or other external DNS. <br> - **DNS Forwarding RuleSets:** Define rules for how DNS queries are forwarded between endpoints and external DNS servers. |
| NSG (Network Security Groups) | Controls traffic to/from subnets within the VNets, acting as a virtual firewall. Ensures critical ports like TCP 445 (for SMB) are allowed where necessary for Azure Files access. |
| UDR (User-Defined Routes) | Custom routing tables applied to subnets to direct traffic through specific next hops (e.g., Azure Firewall) instead of default Azure routing. **Note:** Due to BC Government policies, teams are typically not permitted to create their own UDRs; this will likely require collaboration with the OCIO Platform team to connect the project VNet to the required routes. |
| **Azure Firewall** | A managed, cloud-based network security service deployed in the Hub VNet. It provides centralized network egress filtering, NAT rules, and threat intelligence to protect Azure Virtual Network resources and control traffic between VNets and to the internet. |

For a detailed comparison of network connectivity methods—including VPN, ExpressRoute, and Private Endpoints—see [Azure Files Network Connectivity Options](./OptionsAnalysis/AzureFilesNetworkConnectivityOptionsAnalysis.md).

[Draw.io Version](azure%20files%20express%20route.drawio)
This link points to the `.drawio` source file for the architecture diagram. Ensure that the file `azure files express route.drawio` exists in the same directory as your markdown file. If you want to provide access to the editable diagram (not just the PNG image), this link is correct.

### Monitoring & Security

| **Component** | **Description** |
|---------------|-----------------|
| Azure Monitor + Log Analytics | For collecting and analyzing performance metrics, access logs, and generating alerts across Azure resources. |
| Microsoft Defender for Storage | Provides an additional layer of security by detecting potential threats to Azure Storage accounts, including malware uploads, sensitive data exfiltration, and suspicious access activities. |
| Azure Cost Management | For tracking, reporting, and forecasting storage and other Azure resource costs to ensure cost optimization. |
| **Connection Monitor** | A network performance monitoring service that tracks connectivity latency and packet loss between Azure resources and to external endpoints. |
| **Policy Analytics** | Used to analyze the effectiveness and compliance of Azure Policies applied across your environment. |

#### Joint Responsibility Model for Monitoring

In accordance with BC Government's Cloud Adoption Framework (CAF), monitoring and logging follows a shared responsibility model leveraging centralized components:

- **Core CAF Monitoring Components**:
  - Azure Monitor
  - Azure Activity Logs
  - Azure Metrics
  - Centralized Log Analytics Workspace

- **Project Team Responsibilities**:
  - Configure resource-specific monitoring for Azure Files and Blob Storage
  - Set up appropriate diagnostic settings to capture access patterns, performance metrics, and security events
  - Establish and maintain alerts for critical storage events
  - Consider implementing Azure Monitor Baseline Alerts (AMBA) as a starting point
  - Create custom Azure Dashboards to visualize storage metrics and logs
  
- **Central Platform Team Responsibilities**:
  - Provide centralized Log Analytics workspaces
  - Maintain platform-level monitoring for shared infrastructure
  - Set baseline security monitoring requirements

For this PoC, we'll evaluate both standard Storage Insights and custom monitoring approaches to ensure proper visibility into Azure Files performance, capacity, and access patterns.
  
For complete implementation details, see the [BC Government's Azure Landing Zone Monitoring and Logging Guidelines](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/bc-govs-azure-landing-zone-overview/#monitoring-and-logging)

### Identity & Access Management

| **Component** | **Description** |
|---------------|-----------------|
| Entra ID (Azure AD) | User and group identity management system, synchronized with on-premises Active Directory to provide centralized authentication and authorization. |
| NTFS/ACL Integration | Preserves on-premises NTFS permissions (Access Control Lists) for files and folders when migrating or synchronizing data, integrated through Entra ID synchronization. |
| Azure RBAC | Role-Based Access Control for managing permissions at the Azure Files share level, allowing granular control over who can access specific shares. |

### Tiering & Lifecycle Management

| **Component** | **Description** |
|---------------|-----------------|
| Lifecycle Management Policies (Blob) | Automatically move blobs between Hot, Cool, and Archive tiers based on rules (e.g., age of last modification or access), optimizing storage costs for inactive data. |
| Power BI (Optional) | For creating custom dashboards and reports on usage patterns, tiering effectiveness, and storage costs to aid in decision-making and optimization. |

## How Blob Storage Enables Cool/Archive Tiering

Azure Files does not support automatic tiering of file data to Cool or Archive tiers directly within the file share. To optimize costs for less frequently accessed data:

-   Active files remain in Azure Files (Premium or Standard tiers) for fast access.
-   Inactive or archival files are manually or programmatically moved to Azure Blob Storage.
-   Lifecycle policies in Blob Storage then automate the tiering of these blobs to Cool or Archive tiers based on defined rules, such as age of last modification.

### Azure Files (Standard) supports a Cool tier, but requires manual tiering. Azure Blob Storage is required for automated lifecycle management to Cool/Archive.

## Can You Automate Tiering in Azure Files?

### Azure Files (Premium or Standard):

-   No native support for automated tiering between Premium and Standard tiers.
-   No built-in lifecycle management features directly for file shares like those available for Blob Storage.
-   Tiering between Azure Files tiers or out of Azure Files typically involves manual or scripted data migration.

### Azure Blob Storage:

-   Supports automated tiering via Lifecycle Management Policies.
-   Can automatically move blobs between Hot -> Cool -> Archive tiers based on criteria like last modified time or access patterns, providing significant cost savings for inactive data.

## How to Shift Data from Azure Files Premium to Standard or Blob

### Option 1: Manual or Scripted Migration (Azure Files Premium -> Azure Files Standard)

Use tools like:

-   **AzCopy:** A command-line utility designed for high-performance data transfer to/from Azure Storage.
-   **Robocopy:** (If shares are mounted) A robust file copy utility for Windows, capable of mirroring directories.
-   **Azure Storage Explorer:** A GUI tool for managing Azure Storage resources, allowing drag-and-drop operations for files and folders.

You can automate this process with:

-   **PowerShell scripts**
-   **Azure CLI**
-   **Azure Automation Runbooks**
-   **Scheduled tasks** (on-premises or on Azure VMs)

⚠️ This is a manual or scripted process — Azure Files does not support automatic transitions between Premium and Standard tiers natively.

### Option 2: Migrate to Azure Blob Storage for Automated Tiering

Use tools like:

-   **AzCopy**
-   **Azure Data Factory:** A cloud-based data integration service that can create and orchestrate data movement and transformation workflows.
-   **Custom scripts** (e.g., PowerShell, Python)

Once data is in Azure Blob Storage, apply Blob Lifecycle Policies to automate tiering to Cool/Archive based on your retention and access requirements.

## Deployment Considerations (Infrastructure as Code)

This Azure Files PoC environment will be provisioned using **Terraform scripts** to ensure consistency, repeatability, and adherence to Infrastructure as Code (IaC) principles. Leveraging IaC helps in managing the lifecycle of the infrastructure efficiently.

### Key Terraform Resources for this Architecture:

Implementing this architecture with Terraform will involve defining several core resources from the `azurerm` provider:

* **`azurerm_storage_account`**: The primary resource for creating the Azure Storage Account, which acts as the container for both Azure File Shares and Blob Containers. The `account_kind` (e.g., `StorageV2` or `FileStorage`) is crucial here.
* **`azurerm_storage_share`**: Used to provision individual Azure File Shares within the specified Storage Account.
* **`azurerm_storage_container`**: For creating Blob Storage containers where files can be moved for lifecycle management.
* **`azurerm_storage_management_policy`**: Defines the rules for automatically tiering data within Blob Storage containers (e.g., moving block blobs from Hot to Cool or Archive).
* **`azurerm_virtual_network` & `azurerm_subnet`**: For setting up the Hub and Spoke Virtual Networks and their respective subnets.
* **`azurerm_private_endpoint`**: To establish private connectivity to the Azure Storage Account from the Azure VNet.
* **`azurerm_private_dns_zone` & `azurerm_private_dns_zone_virtual_network_link`**: For proper DNS resolution of private endpoints.
* **`azurerm_network_security_group`**: To control inbound and outbound network traffic to subnets.
* **`azurerm_route_table` & `azurerm_route`**: For defining custom routing, though it's noted that the OCIO Platform team typically manages UDRs in the BC Government context.
* **`azurerm_virtual_network_gateway`**: For configuring VPN and ExpressRoute gateways.
* **`azurerm_firewall`**: For deploying and configuring Azure Firewall in the Hub VNet.
* **`azurerm_storage_sync_service`, `azurerm_storage_sync_group`, `azurerm_storage_sync_cloud_endpoint`**: (If Azure File Sync is part of the PoC) For setting up the Azure File Sync infrastructure.

See also [Terraform Resources for Azure PoC](./TerraformResourcesForAzurePoC.md)

### BC Government Specifics and Best Practices:

* **Getting started with Azure:** 
    * [developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/bc-govs-azure-landing-zone-overview](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/bc-govs-azure-landing-zone-overview/)

* **UDR Management:** As noted in the Networking section, the creation and management of User-Defined Routes (UDRs) for ExpressRoute integration will likely involve collaboration with the OCIO Platform team due to BC Government policies.
* **Azure File Sync Traffic:** Any hybrid Azure File Sync approach aiming to reduce ExpressRoute traffic for less sensitive file shares will require consultation with an OCIO security architect.
* **Module Structure:** For insights into how Terraform modules are typically structured within the BC Government, refer to public-facing repositories like:
    * [bcgov/azure-lz-terraform-modules](https://github.com/bcgov/azure-lz-terraform-modules/tree/main)
* **Code Examples:** Practical examples for common Azure patterns using Terraform can be found at:
    * [bcgov/azure-lz-samples](https://github.com/bcgov/azure-lz-samples)
    * [bcgov/azure-startup-sample-app-containers](https://github.com/bcgov/azure-startup-sample-app-containers)
* **Policies & Best Practices:** Adherence to BC Government's technical documentation on Infrastructure as Code and CI/CD best practices for public cloud environments is crucial.
    * [developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)

## References

-   [Microsoft Learn – Configure a lifecycle management policy](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-lifecycle-management-concepts)
-   [Microsoft Tech Community – Azure Storage Options Guide](https://techcommunity.microsoft.com/blog/nonprofittechies/azure-storage-options---a-guide-to-choosing-the-right-storage-option/4412411)