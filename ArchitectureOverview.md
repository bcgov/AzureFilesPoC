
# Azure Files PoC Architecture Overview

## Overview

This architecture supports the evaluation of Azure Files with optional integration to Azure Blob Storage. It is designed to ensure secure, performant, and compliant access to large media files (e.g., video/audio) from both on-premises and cloud environments.

## Architecture Diagram

![Azure Files ExpressRoute Diagram](azure%20files%20express%20route.drawio.png)


This diagram illustrates the hybrid connectivity model using VPN and ExpressRoute, with Azure Files accessed via Private Endpoint and optional integration with Azure Blob Storage for tiering.

## Components

### Core Storage & Access

| **Component** | **Description** |
|---------------|-----------------|
| Azure Files (Premium Tier) | For high-performance SMB file shares (e.g., real-time playback, active evidence access). |
| Azure Files (Standard Tier) | For general-purpose SMB shares with lower cost; supports manual tiering to Cool. |
| Azure Storage Account | Hosts Azure Files shares and optionally Blob Storage containers. |
| Azure Blob Storage (Hot/Cool/Archive) | Used for storing large, infrequently accessed files with lifecycle-based tiering. |

### Networking & Connectivity

| **Component** | **Description** |
|---------------|-----------------|
| VPN Gateway | Enables secure access from on-premises to Azure over VPN (short-term). |
| ExpressRoute Circuit | Private, high-performance connection from on-prem to Azure (long-term). |
| ExpressRoute Gateway | Azure-side gateway for ExpressRoute connectivity. |
| Azure Virtual Network (VNet) | Hosts the private endpoint and other Azure resources. |
| Private Endpoint for Azure Files | Maps a private IP from your VNet to the Azure Storage account. |
| Private DNS Zone | Resolves private endpoint names (e.g., privatelink.file.core.windows.net). |
| NSG (Network Security Groups) | Controls traffic to/from subnets (ensure TCP 445 is allowed). |
| UDR (User-Defined Routes) | Custom routing to direct traffic through ExpressRoute or VPN. |

For a detailed comparison of network connectivity methods—including VPN, ExpressRoute, and Private Endpoints—see [Azure Files Network Connectivity Options](AzureFilesNetworkConnectivityOptionsAnalysis.md).

[Draw.io Version](azure%20files%20express%20route.drawio)
This link points to the `.drawio` source file for the architecture diagram. Ensure that the file `azure files express route.drawio` exists in the same directory as your markdown file. If you want to provide access to the editable diagram (not just the PNG image), this link is correct.

### Monitoring & Security

| **Component** | **Description** |
|---------------|-----------------|
| Azure Monitor + Log Analytics | For performance metrics, access logs, and alerts. |
| Microsoft Defender for Storage | Threat detection and compliance monitoring. |
| Azure Cost Management | For tracking and forecasting storage costs. |

### Identity & Access Management

| **Component** | **Description** |
|---------------|-----------------|
| Entra ID (Azure AD) | User and group identity management synchronized with on-premises AD. |
| NTFS/ACL Integration | Preserves on-premises NTFS permissions for files/folders through Entra ID synchronization. |
| Azure RBAC | Role-based access control for share-level permissions. |

### Tiering & Lifecycle Management

| **Component** | **Description** |
|---------------|-----------------|
| Lifecycle Management Policies (Blob) | Automatically move blobs between Hot, Cool, and Archive tiers based on rules. |
| Power BI (Optional) | For custom dashboards and reporting on usage, tiering, and costs. |

## How Blob Storage Enables Cool/Archive Tiering

Azure Files does not support automatic tiering. To optimize costs:

- Active files remain in Azure Files (Premium or Standard).
- Inactive files are moved to Azure Blob Storage.
- Lifecycle policies in Blob Storage automate tiering to Cool or Archive tiers.

### Azure Files (Standard) supports a Cool tier, but manual tiering only. Blob Storage is required for automated lifecycle management.

## Can You Automate Tiering in Azure Files?

### Azure Files (Premium or Standard):

- No native support for automated tiering between Premium and Standard.
- No lifecycle management like Blob Storage.
- Tiering is manual and involves data migration.

### Azure Blob Storage:

- Supports automated tiering via Lifecycle Management Policies.
- Can automatically move blobs between Hot -> Cool -> Archive based on last modified time or access patterns.

## How to Shift Data from Azure Files Premium to Standard or Blob

### Option 1: Manual or Scripted Migration (Premium -> Standard)

Use tools like:

- AzCopy
- Robocopy (if shares are mounted)
- Azure Storage Explorer

You can automate this with:

- PowerShell scripts
- Azure CLI
- Azure Automation Runbooks
- Scheduled tasks

⚠️ This is a manual or scripted process — Azure does not support automatic transitions between Premium and Standard tiers.

### Option 2: Migrate to Azure Blob Storage for Tiering

Use AzCopy, Azure Data Factory, or custom scripts to move files from Azure Files to Blob Storage.

Apply Blob Lifecycle Policies to automate tiering to Cool/Archive.

## References

- [Microsoft Learn – Configure a lifecycle management policy](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-lifecycle-management-concepts)
- [Microsoft Tech Community – Azure Storage Options Guide](https://techcommunity.microsoft.com/blog/nonprofittechies/azure-storage-options---a-guide-to-choosing-the-right-storage-option/4412411)
