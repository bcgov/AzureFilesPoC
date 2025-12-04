# Azure Bastion Guidance (BC Gov)

_Last updated: July 30, 2025_

## Overview
Azure Bastion is a fully managed PaaS service for secure RDP/SSH connectivity to virtual machines via private IP, directly over TLS from the Azure portal.

## Bastion Session Cached Credentials
- When using a VM in a VNet to access the Azure portal, browser sessions may cache credentials.
- If sharing the VM, always use a private/incognito browser session or log out after each session to prevent others from accessing your cached credentials.

## Which Azure Bastion SKU to Use?
- **Minimum SKU:** Developer (does not require AzureBastionSubnet, but has feature limitations).
- For SKUs other than Developer, Bastion requires:
  - A Virtual Network
  - A subnet named `AzureBastionSubnet` (address range must be /26 or larger, e.g., /25 or /24)
- Review [Microsoft Bastion SKU documentation](https://learn.microsoft.com/en-us/azure/bastion/bastion-sku) for details.

## Bastion Subnet Size
- Review [Microsoft documentation](https://learn.microsoft.com/en-us/azure/bastion/bastion-subnet) for subnet size requirements.
- `AzureBastionSubnet` must be /26 or larger.

## Network Security Group (NSG) Rules
- Create appropriate ingress and egress NSG rules for Bastion traffic.
- See [Working with NSG access and Azure Bastion](https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg) for rule details.
- Rule priority numbers do not need to match examples, but configuration must match.

## Deployment Example
- Microsoft provides multiple deployment guides for Azure Bastion.
- BC Gov provides a Terraform module that deploys the required subnet, NSG (with all rules), and Bastion host (Basic SKU).
- Find the module in the Azure Landing Zone Samples repo under `/tools/bastion/`.
- Review the module README for usage instructions.

## Cost Savings Options
- To save costs, schedule Bastion deletion at the end of the day and recreation in the morning if only needed during business hours.
- See [Save Cost with Azure Bicep Deployment Stacks](https://techcommunity.microsoft.com/t5/azure-architecture-blog/save-cost-with-azure-bicep-deployment-stacks/ba-p/3909642) for an example (concepts apply to Terraform too).
- If using the sample code, note it creates `AzureBastionSubnet` as well. Adjust the code to avoid deleting the subnet, or ensure address space is available when recreating.

---

For more details, see the [BC Gov Public Cloud TechDocs: Azure Bastion](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/tools/bastion/).
