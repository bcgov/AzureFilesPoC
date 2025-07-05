# BC Gov On-Premises to Azure Connectivity: ExpressRoute & VPN Gateway

_Last updated: July 2025_

## Current Status
- **ExpressRoute is NOT yet available in production** (only in internal Test environment).
- **Blockers:**
  - Pending on-prem firewall changes
  - Azure VWAN IPSec tunneling issue with new Equinix hardware (Microsoft ticket open)

### What to Use Now: Azure VPN Gateway
- **Until ExpressRoute is live, use a Site-to-Site VPN tunnel via Azure VPN Gateway.**
- **Connectivity Path:**
  - On-Prem Firewall → Public Internet → Azure VPN Gateway
  - IPSec tunnel is established between your on-prem device and Azure.
  - Routing is managed via VWAN route tables (will later support ExpressRoute).

### What Happens When ExpressRoute Goes Live
- VNETs will associate with a dedicated route table in the VWAN hub.
- ExpressRoute routes will be propagated automatically.
- You will reach the edge of the data centre; internal routing (e.g., IDIR domain) may still require OCIO Networks support.

---

## Step-by-Step Plan: Enable Secure On-Premises Access to Azure Files via Site-to-Site VPN

### 1. Prerequisites & On-Premises Requirements
- **Firewall:**
  - Allow outbound UDP 500 and 4500 (IKE/IPSec)
  - Allow ESP (IP protocol 50) if NAT-T is not used
  - Create rules for Azure VPN Gateway public IPs
  - Enable NAT Traversal (NAT-T) if firewall is behind NAT
- **VPN Device:**
  - Use a supported device (Cisco, Fortinet, Palo Alto, etc.)
  - Firmware must support IKEv2
  - Configure with:
    - Pre-shared key (PSK)
    - Azure VPN Gateway public IP
    - IKE/IPSec parameters (encryption, hashing, DH group)

### 2. Azure Configuration
- **VWAN Setup:**
  - VWAN Hub deployed in region
  - VPN Gateway created in VWAN hub
  - Configure Site-to-Site VPN:
    - Define on-prem public IP and address space
    - Use shared key for authentication
- **Route Table:**
  - Create custom route table in VWAN hub
  - Associate spoke VNETs
  - Enable propagation from VPN Gateway

### 3. Tunnel Establishment & Routing
- Azure initiates/responds to IKEv2 negotiation
- Tunnel established (IKE Phase 1 & 2)
- Monitor tunnel health in Azure Portal or Network Watcher
- Add on-prem routes to Azure address space in internal routers/firewalls
- Azure routes traffic to on-prem via VPN Gateway

### 4. DNS Resolution
- Confirm that on-prem DNS can resolve Azure Files private endpoint names (e.g., `privatelink.file.core.windows.net`).
- The Azure platform will automatically create the required DNS A-record in the central Private DNS Zone after the private endpoint is provisioned.
- If needed, configure conditional forwarding from on-prem DNS to the Azure Private DNS Resolver. Forward queries for Azure PaaS private endpoint zones (e.g., `privatelink.file.core.windows.net`) to the resolver IPs provided by the platform team.
- Do not attempt to create or attach your own Private DNS Zone; all DNS is managed centrally.
- For custom DNS needs, submit a request to the Public Cloud team.

### 5. Network Security Groups (NSGs) & Firewall Rules
- Ensure NSGs on the storage subnet allow SMB (TCP 445) and any other required protocols from on-prem IP ranges.
- Confirm central firewall allows required traffic (SMB, DNS, etc.) between on-prem and Azure Files.
- Request any required rule changes via the Public Cloud team.

### 6. Azure Files Permissions
- Assign appropriate Azure RBAC roles (e.g., Storage File Data SMB Share Contributor) to end-user groups or service principals.
- Ensure users are authenticated via Entra ID (Azure AD) and have access to the file share.

### 7. Mount Azure File Share & Testing
- Provide users with the UNC path to the Azure File Share (e.g., `\\<storageaccount>.file.core.windows.net\<sharename>`).
- Use Entra ID credentials for authentication.
- Test mounting from an on-prem device to confirm access.
- Run ping/traceroute from on-prem to Azure VMs to verify connectivity.

### 8. Monitoring & Troubleshooting
- Use Azure Network Watcher, logs, and monitoring tools to verify connectivity and diagnose issues.
- Monitor for dropped packets, authentication failures, or DNS issues.
- Monitor logs on both sides for tunnel status and dropped packets.

---

## Site-to-Site VPN: Required Components (BC Gov Landing Zone)

```mermaid
graph TD
  subgraph On-Premises
    FW[On-Prem Firewall]
    VPN[On-Prem VPN Device]
    LAN[Internal Network]
    LAN --> FW
    FW --> VPN
  end

  subgraph Azure Landing Zone
    vWAN[Azure Virtual WAN Hub]
    VPNGW[Azure VPN Gateway]
    HubVNet[Hub VNet]
    SpokeVNet[Spoke VNet (Project Set)]
    PE[Private Endpoint]
    SA[Storage Account / Azure Files]
    DNS[Central Private DNS Zone]
    vWAN --> VPNGW
    VPNGW --> HubVNet
    HubVNet --> SpokeVNet
    SpokeVNet --> PE
    PE --> SA
    SpokeVNet --> DNS
  end

  VPN -- IPSec Tunnel --> VPNGW
  DNS -.-> OnPremDNS[On-Prem DNS (Conditional Forwarder)]
  OnPremDNS -.-> DNS
```

**Legend:**
- **On-Premises:** Your internal network, firewall, and VPN device.
- **Azure Landing Zone:**
  - **vWAN Hub:** Centralized hub for all connectivity (VPN, ExpressRoute, etc.).
  - **VPN Gateway:** Azure-side endpoint for the IPSec tunnel.
  - **Hub VNet:** Central VNet for shared services and routing.
  - **Spoke VNet:** Project-specific VNet for workloads (already provisioned).
  - **Private Endpoint:** Secure, private access to Azure Files/Storage.
  - **Central Private DNS Zone:** Platform-managed DNS for private endpoints.

**Flow:**
- IPSec tunnel is established between the on-prem VPN device and Azure VPN Gateway in the vWAN hub.
- Traffic routes from on-prem through the firewall and VPN device, into Azure via the vWAN hub, then to the Hub VNet and Spoke VNet.
- Private Endpoints provide secure access to storage resources.
- DNS resolution for private endpoints is handled by the central Private DNS Zone, with conditional forwarding from on-prem DNS if required.

---

## Key BC Gov Landing Zone Constraints & Reminders
- **No custom UDRs or route tables:** All routing is managed centrally. Request changes via the Public Cloud team.
- **No VNet peering or new VNets:** All connectivity is via the vWAN hub and spoke model.
- **Centralized DNS:** Private DNS Zones are platform-managed. For custom DNS, submit a request.
- **All subnets must have NSGs:** Required at creation time.
- **All subnets are private:** No direct outbound internet access; all egress is via the central firewall.
- **No public IPs or open management ports:** Use Azure Bastion for secure access.
- **ExpressRoute and VPN are mutually exclusive:** Migration is managed by the platform team.
- **Monitoring and diagnostics:** Default diagnostic settings are policy-enforced and cannot be deleted.
- **Tagging and naming:** Follow BC Gov conventions and tagging policies.
- **Role assignments:** Managed via Entra ID security groups at the management group level.
- **Firewall and security:** All traffic is inspected by the central firewall (TLS inspection, IDPS, URL filtering).
- **Change management:** All core networking changes must go through the Public Cloud team.

---

## Exposing Services to the Internet & User Defined Routes (UDRs)

- Use Azure Application Gateway (with Web Application Firewall/WAF) to securely expose applications to the internet, as direct public IPs and open management ports are not permitted in the BC Gov Landing Zone.
- Backend health probes for Application Gateway may show as "Unknown" if traffic is routed through the central firewall. In such cases, a custom User Defined Route (UDR) may be required to ensure correct health probe routing. **Custom UDRs cannot be created directly; you must request them via the Public Cloud team.**
- For Azure File Sync and other services that may require special routing, always consult with the platform and security teams to ensure compliance with government policy and architecture standards. See the Architecture Overview for more details.
- All routing, including UDRs, is centrally managed. No custom UDRs or route tables are permitted without explicit approval and implementation by the platform team.

> **Note:** For government-specific policies regarding User-Defined Routes (UDRs), Application Gateway, and Azure File Sync, always consult with platform and security teams as referenced in the architecture overview and landing zone guardrails.

**Tip:**
- Coordinate with your network, security, and platform teams for any required changes or troubleshooting.
- For more details, see:
  - [BCGov-NetworkingSummary.md](./BCGov-NetworkingSummary.md)
  - [BCGov-PrivateDNSandEndpoints.md](./BCGov-PrivateDNSandEndpoints.md)
  - [AzureLandingZone_Guardrails_Summary.md](./AzureLandingZone_Guardrails_Summary.md)