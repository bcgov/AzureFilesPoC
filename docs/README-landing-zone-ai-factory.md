# Azure Landing Zone for AI Factory

This document summarizes the architecture and required Azure resources for deploying a secure, BC Gov-compliant landing zone to support AI Factory workloads, referencing the provided architecture diagram and inventory.

## Overview
This landing zone is designed to provide a secure, scalable foundation for running AI Factory workloads in Azure. It includes all core networking, security, compute, identity, and monitoring resources needed for a compliant deployment, with private connectivity and support for Azure Foundry and AI services.

## Architecture Diagram
See [`landing-zone-architecture.mmd`](./landing-zone-architecture.mmd) for a visual representation of all required Azure resources and their relationships. The diagram includes:
- Resource group
- Networking (VNet, subnets, NSGs)
- Bastion host
- Virtual machine
- Azure Foundry and project
- Private endpoints
- Storage, Key Vault, Log Analytics, Managed Identity

## Required Azure Resources
A full inventory of required objects is provided in [`required-azure-objects.md`](./required-azure-objects.md). Key resources include:
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
- Deploying all required Azure resources using Infrastructure as Code (Bicep or Terraform)
- Ensuring all networking, security, and compliance guardrails are in place
- Enabling secure, private connectivity for AI Factory workloads
- Integrating Azure Foundry and project resources for AI development
- Setting up monitoring, logging, and managed identities for operational excellence

## Next Steps
1. Review the architecture diagram and required objects list.
2. Choose your preferred deployment approach (Terraform or Bicep).
3. Follow the deployment scripts and documentation to provision your landing zone.
4. Validate connectivity, security, and compliance for your AI Factory workloads.

---

For detailed resource definitions, see [`required-azure-objects.md`](./required-azure-objects.md).
For the full architecture, see [`landing-zone-architecture.mmd`](./landing-zone-architecture.mmd).
