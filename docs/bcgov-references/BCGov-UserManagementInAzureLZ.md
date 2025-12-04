# User Management in the BC Gov Azure Landing Zone

_Last updated: July 2025_

## Overview
This resource summarizes best practices and requirements for managing user access in your Azure Landing Zone (LZ) project set, based on [BC Gov Public Cloud Technical Documentation](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/design-build-deploy/user-management/). For full details and procedures, refer to the official documentation.

## Project Set Structure
- Your project set consists of up to four Azure subscriptions (Dev, Test, Prod, Tools) grouped under a single management group, all prefixed with your license plate (e.g., `abc123`).
- Access is managed centrally at the management group level and propagates to all subscriptions.

## Permission Tiers
- **Reader:** View-only access
- **Contributor:** Can create/manage resources, but cannot modify access permissions
- **Owner:** Full administrative access (subject to policy restrictions)
- All actions are subject to Azure Policy restrictions, which may override RBAC permissions.

## Security Group Structure
- Privileged access (Owner, Contributor, Reader) is managed via Entra ID security groups named:
  - `DO_PuC_Azure_Live_{LicensePlate}_Owners`
  - `DO_PuC_Azure_Live_{LicensePlate}_Contributors`
  - `DO_PuC_Azure_Live_{LicensePlate}_Readers`
- These groups are assigned roles at the management group level, ensuring consistent access across all subscriptions.

## What You Can and Cannot Do
- **Can:**
  - Manage membership in the above security groups to grant privileged access
  - Create custom roles for specific needs
  - Assign users/groups directly to non-privileged roles at Subscription, Resource Group, or Resource level (principle of least privilege)
  - Create/manage service principals and managed identities
  - Create/manage resources within your subscriptions (subject to policy)
- **Cannot:**
  - Assign users/groups directly to privileged roles (Owner/Contributor) outside the security groups
  - Bypass Azure Policy restrictions

## Managing Group Membership
- Use Microsoft Account Management or the Azure Portal (Entra ID > Groups) to add/remove members from your security groups.

## Best Practices
- Use security groups for broad, privileged access; use direct assignments for granular, non-privileged access.
- Always follow the principle of least privilege.
- Regularly audit group memberships and direct assignments; document your access structure.
- Avoid long-lived credentials; prefer managed identities or short-lived credentials.
- Understand control-plane vs. data-plane access differences; some data access requires additional roles.

## Service Principals & Managed Identities
- Service principals define what an application can do in Azure; managed identities are automatically managed by Azure for secure resource access.
- For more, see [What are managed identities for Azure resources?](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) and [Register a Microsoft Entra app and create a service principal](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal).

## Need Help?
- Contact the Public Cloud team for support with user management or access structure questions.

---

**Reference:**
- [BC Gov Public Cloud Technical Documentation: User Management in the Azure Landing Zone](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/design-build-deploy/user-management/)
