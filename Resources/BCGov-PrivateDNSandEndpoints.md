# Azure Landing Zone: Private DNS and Private Endpoints

_Last updated: May 5, 2025_

## Overview

When working in the BC Gov Azure Landing Zone, private connectivity and DNS integration are tightly controlled for security and compliance. This document summarizes key points and best practices for Private Endpoints and Private DNS Zones.

---

## Private Endpoints and DNS Integration

- **Private-only Connectivity:**
  - Many Azure PaaS services (e.g., Databases, Key Vaults) are restricted to private-only access. You must deploy a Private Endpoint for these services.

- **Private DNS Integration Setting:**
  - When creating a Private Endpoint, the Azure portal defaults the "Integrate with private DNS zone" option to **Yes**.
  - **Best Practice:** Select **No**. The Azure Landing Zone is already configured with centralized custom Private DNS Zones managed by the platform team.

- **DNS Record Creation:**
  - After deploying a Private Endpoint, a DNS A-record will be automatically created in the central Private DNS Zone (usually within ~10 minutes), pointing to the resource's private IP.
  - This enables access to the resource using its DNS name from within the private network.

- **Access Limitations:**
  - These resources are not accessible from outside the VNet.
  - To access them, use Azure Bastion or Azure Virtual Desktop (AVD) from within the VNet.
  - In the future, ExpressRoute may provide on-premises access. VPN connectivity is not permitted in our Landing Zone for this project.

---

## Custom Private DNS Zones

- **Centralized Management:**
  - The Azure Landing Zone uses centralized custom Private DNS Zones for all supported Azure services.
  - Creating your own custom Private DNS Zone is generally **not recommended**.

- **Exceptions:**
  - If you need a Private DNS Zone for a third-party service (e.g., Confluent Cloud) not covered by the central zones, submit a support request to the Public Cloud team.
  - The team will help create and attach the custom DNS Zone to the central Private DNS Resolver.

- **VNet Attachment Warning:**
  - Attaching a custom Private DNS Zone directly to your VNet will **not work**. All DNS queries are routed through the central Private DNS Resolver.

---

## References

- [BC Gov Azure Best Practices: Be Mindful](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/be-mindful/)

---

**Summary:**
- Use Private Endpoints for private-only PaaS resources.
- Do **not** integrate with a new private DNS zone during endpoint creation—use the existing central zones.
- For custom DNS needs, always coordinate with the platform team.
- Access private-only resources from within the VNet using Bastion or AVD.
