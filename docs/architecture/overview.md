# Azure Landing Zone Architecture

This document provides an overview of the Azure landing zone architecture for the Azure Files PoC, which has evolved to support both **Azure Files storage** and **Azure AI Foundry** workloads.

## Architecture Evolution

This project started as an Azure Files evaluation and evolved to include Azure AI Foundry:

| Phase | Focus | IaC Approach |
|-------|-------|--------------|
| **Phase 1** | Azure Files + Storage evaluation | Terraform + GitHub Actions CI/CD |
| **Phase 2** | Azure AI Foundry + private endpoints | Bicep + Azure CLI (current) |

Both approaches are valid patterns. The Bicep scripts are the **active deployment method**; Terraform code is archived for reference.

## Current Architecture (AI Foundry + Azure Files)

The landing zone provides a secure, BC Gov-compliant foundation with:
- **Zero-trust networking** via private endpoints
- **Cross-region deployment** (infrastructure in canadacentral, AI services in canadaeast)
- **Secure access** via Bastion (no public IPs on VMs)
- **Managed identity** for passwordless authentication

### Architecture Diagrams

| Diagram | Description |
|---------|-------------|
| [`landing-zone.mmd`](./landing-zone.mmd) | Current AI Foundry architecture (Mermaid) |
| [`azure_files_poc_architecture_diagram.drawio`](./azure_files_poc_architecture_diagram.drawio) | Complete PoC architecture including AI Foundry (Draw.io) |

### Key Resources

See [`resource-inventory.md`](./resource-inventory.md) for the complete list. Key components:
- **Resource Group**: Central container for all landing zone resources
- **Networking**: Existing VNet, dedicated subnets for VM, Bastion, and Private Endpoints
- **NSGs**: Network Security Groups for each subnet
- **Bastion**: Secure remote access to VMs
- **Virtual Machine**: Compute for workloads or self-hosted runners
- **Azure Foundry/Workspace**: For AI Factory and project resources
- **Private Endpoints**: Secure access to Storage and Key Vault
- **Storage Account**: For data and diagnostics
- **Key Vault**: Secure secrets management
- **Log Analytics Workspace**: Centralized monitoring
- **User-Assigned Managed Identity**: For secure, managed access

## What You Will Be Doing
- Deploying all required Azure resources using **Bicep scripts** (primary method)
- Ensuring all networking, security, and compliance guardrails are in place
- Enabling secure, private connectivity for AI Factory workloads
- Integrating Azure Foundry and project resources for AI development
- Setting up monitoring, logging, and managed identities for operational excellence

## Related Documentation

| Document | Description |
|----------|-------------|
| [`azure-files-overview.md`](./azure-files-overview.md) | Original Azure Files architecture (hub-spoke, storage tiers) |
| [`network-diagram.md`](./network-diagram.md) | IP addressing and subnet layout |
| [`resource-inventory.md`](./resource-inventory.md) | Complete Azure resource list |

## Next Steps
1. Review the architecture diagrams
2. Follow the [Deployment Guide](../guides/deployment-guide.md) to provision resources
3. Test AI models using the [AI Model Testing Guide](../guides/ai-model-testing.md)
4. Validate connectivity and security from the VM

---

For detailed resource definitions, see [`resource-inventory.md`](./resource-inventory.md).
For the full architecture, see [`landing-zone.mmd`](./landing-zone.mmd).
For deployment instructions, see the [Deployment Guide](../guides/deployment-guide.md).
