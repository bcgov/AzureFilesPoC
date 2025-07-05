# Networking in the Azure Landing Zone (BC Gov)

_Last updated: June 16, 2025_

**Source:** [BC Gov Azure Networking Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/design-build-deploy/networking/)

---

## Overview
This document summarizes the key networking components, security controls, and best practices for working within the BC Gov Azure Landing Zone.

---

## Subnet Planning
- **Plan subnets before deploying resources** to avoid future re-architecture.
- Each Project Set receives a dedicated Virtual Network (VNet) with ~251 usable IPs (default /24).
- Microsoft reserves 5 IPs per subnet; contact the Public Cloud team if you need more than a /24.

## Virtual Network (VNet)
- Each Project Set has a VNet for resource isolation and security.
- The VNet is connected to the central hub (vWAN) and routes all traffic (internet and private) through the central firewall.
- No subnets are pre-created; teams must create their own subnets for their workloads.

## Subnet Security Controls
- **Every subnet must have an associated Network Security Group (NSG).**
  - Recommended: Create the NSG first, then the subnet with the NSG attached.
  - All subnets must be private (no direct internet access).
- For Terraform guidance, see the IaC and CI/CD documentation.

## Spoke-to-Spoke Connectivity
- Disabled by default for security.
- If needed (e.g., for Dev/Test/Prod/Tools environments), submit a request to the Public Cloud team for review and firewall changes.

## Internet Connectivity
- All outbound traffic is routed through the central firewall for inspection and compliance.
- Advanced features include:
  - TLS inspection
  - Intrusion Detection/Prevention (IDPS)
  - URL filtering and web category controls
  - Protection against malicious and East-West traffic

## Exposing Services to the Internet
- Use Azure Application Gateway (with WAF) to expose applications securely.
- Backend health may show as "Unknown" due to firewall routing; a custom User Defined Route (UDR) is required (request via Public Cloud team).

## VNet Integration vs. Private Endpoints
- For Azure PaaS services, **Private Endpoints** are recommended over VNet integration or Service Endpoints.
- Private Endpoints trigger automation to create DNS records in the central Private DNS Zone.
- See the Private Endpoints and DNS section for more details.

## Protected Network Resources
- The following actions are restricted or not allowed:
  - Modifying VNet DNS settings or address space
  - Creating ExpressRoute circuits, VPNs, gateways, or route tables
  - Creating new VNets or VNet peering
  - Deleting default diagnostic settings (setbypolicy)
- All such changes must go through the Public Cloud team.

---

**Summary:**
- Plan your subnetting and NSGs before deploying resources.
- All networking is routed and secured centrally.
- Use Private Endpoints for PaaS services and do not attempt to manage protected network resources directly.
- For advanced networking needs, always coordinate with the Public Cloud team.
