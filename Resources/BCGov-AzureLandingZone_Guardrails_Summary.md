# Azure Landing Zone Guardrails: What You Need to Know

_Last updated: May 5, 2025_

**Source:** [BC Gov Azure Landing Zone Guardrails](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/get-started-with-azure/guardrails/)

---

## Overview
Azure Landing Zone "guardrails" are security and compliance rules enforced by Azure Policy to ensure a secure, compliant, and cost-effective cloud environment. These guardrails provide automatic checks and balances, blocking or auto-configuring resources to meet standards like CCCS Medium (Canada Federal PBMM).

---

## Key Guardrail Areas

### 1. Resource Deployment Restrictions
- **Allowed Locations:** Only Canada Central and Canada East are permitted for resource groups and resources.
- **Denied Resource Types:** Certain resource types are blocked from creation.

### 2. Networking Restrictions
- **No Public IPs:** Public IP addresses and public management ports (SSH/RDP) are denied.
- **NSG Requirement:** Every subnet must have a Network Security Group (NSG).
- **Private Endpoints:** Required for most PaaS services; public access is denied.
- **No VNet Creation/Peering:** VNets and peering are centrally managed and cannot be created or changed by users.
- **Centralized DNS:** Private DNS Zones are managed centrally; custom DNS zones for supported PaaS services are denied.

### 3. Security Requirements
- **HTTPS Only:** Enforced for web apps, storage, APIs, etc.
- **Minimum TLS Version:** Usually TLS 1.2 or higher.
- **Defender for Cloud:** Enabled by default.
- **Key Vault:** Soft delete, purge protection, and RBAC enforced; strict key/secret/certificate requirements.
- **No weak/outdated protocols.**

### 4. Data Protection
- **Customer-Managed Keys (CMK):** Required for many services; managed in Azure Key Vault.
- **Key/Secret Expiry:** Enforced for Key Vault and Managed HSM.

### 5. Cost Optimization
- **Unused Resources:** Policies audit for unattached disks, unused public IPs, empty app service plans, etc.

### 6. Identity & Access Management
- **Entra ID Security Groups:** Access is managed through standardized security groups at the management group level.
- **No Direct Role Assignments:** All access is via security groups, except for service principals.

### 7. Service-Specific Guardrails
- **AKS:** No privileged containers, minimum TLS, HTTPS ingress, etc.
- **SQL/Managed Instance:** Auditing, TDE, threat detection, private endpoints, AAD-only auth.
- **Storage:** Secure transfer, minimum TLS, no public blob access, no local users.
- **Automation, Machine Learning, Databricks, Logic Apps, etc.:** Various restrictions on public access, protocols, and configuration.

### 8. Monitoring & Tagging
- **Diagnostic Settings:** Centralized log/metric collection; deletion is blocked.
- **Tag Inheritance:** Automatic tagging from subscription to resources.

---

## Important Considerations
- **Exceptions:** Rare and require formal review.
- **Audit vs. Deny:** Audit policies report non-compliance; Deny policies block deployments; DeployIfNotExists/Modify policies auto-configure resources.
- **Order of Enforcement:** Deny policies take precedence over audit.
- **Subject to Change:** Guardrails and policies may be updated; check with the platform team for details.

---

**Summary:**
- Guardrails are enforced automatically to ensure security, compliance, and cost control.
- Most restrictions are handled by policy; users should design infrastructure to comply with these rules.
- For technical details, refer to the Azure Policy definitions or contact the platform team.
- The [bcgov/azure-lz-samples](https://github.com/bcgov/azure-lz-samples) repository provides up-to-date, modular, and policy-aligned Terraform samples for BC Gov Azure Landing Zones. See [BCGov-AzureLandingZoneSamplesSummary.md](BCGov-AzureLandingZoneSamplesSummary.md) for a summary and recommendations for alignment.
