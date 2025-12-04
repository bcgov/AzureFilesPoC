# Azure Files PoC - Documentation Index

This folder contains all documentation for the Azure Files Proof of Concept project, including deployment guides, architecture references, and operational runbooks.

## 📚 Quick Start

| If you want to... | Read this |
|-------------------|-----------|
| Deploy the full infrastructure | [Deployment Guide](./guides/deployment-guide.md) |
| Test an AI model | [AI Model Testing Guide](./guides/ai-model-testing.md) |
| Connect to the VM | [Bastion Connection Guide](./runbooks/bastion-connection.md) |
| Understand the architecture | [Architecture Overview](./architecture/overview.md) |

---

## 📁 Documentation Structure

```
docs/
├── README.md                    # This file - documentation index
├── guides/                      # Step-by-step guides
│   ├── deployment-guide.md      # Full infrastructure deployment
│   ├── ai-model-testing.md      # AI model deployment & testing
│   ├── azure-cli-setup.md       # Azure CLI configuration
│   ├── ssh-key-setup.md         # SSH key creation for VM access
│   └── cicd-runner-setup.md     # Self-hosted GitHub runner setup
├── runbooks/                    # Operational procedures
│   ├── bastion-connection.md    # Connect to VM via Bastion
│   ├── vm-shutdown.md           # VM shutdown & cost management
│   └── vm-updates.md            # VM maintenance & updates
├── architecture/                # Architecture & design
│   ├── overview.md              # Landing zone overview
│   ├── azure-files-overview.md  # Azure Files architecture (original scope)
│   ├── network-diagram.md       # IP/subnet diagrams
│   ├── resource-inventory.md    # Required Azure objects
│   └── landing-zone.mmd         # Mermaid architecture diagram
├── reference/                   # Reference documentation
│   ├── poc-plan.md              # PoC objectives & evaluation criteria
│   ├── deployment-scripts.md    # Script reference manual
│   └── subnet-nsg-scoping.md    # Deployment scoping rules
├── bcgov-references/            # BC Government Azure resources
│   ├── azure-lz-samples/        # Landing zone code samples
│   └── *.md                     # Various BC Gov Azure guides
```

---

## 🚀 Guides

Step-by-step instructions for deployment and configuration.

| Guide | Description |
|-------|-------------|
| [Deployment Guide](./guides/deployment-guide.md) | Complete infrastructure deployment (Phases 1-5) |
| [AI Model Testing](./guides/ai-model-testing.md) | Deploy and test AI models via private endpoint |
| [Azure CLI Setup](./guides/azure-cli-setup.md) | Configure Azure CLI and PowerShell |
| [SSH Key Setup](./guides/ssh-key-setup.md) | Create SSH keys for VM access |
| [CI/CD Runner Setup](./guides/cicd-runner-setup.md) | Self-hosted GitHub Actions runner |

---

## 🔧 Runbooks

Operational procedures for day-to-day tasks.

| Runbook | Description |
|---------|-------------|
| [Bastion Connection](./runbooks/bastion-connection.md) | Connect to VM via Azure Bastion |
| [VM Shutdown](./runbooks/vm-shutdown.md) | Stop VMs and manage costs |
| [VM Updates](./runbooks/vm-updates.md) | Apply security patches and updates |

---

## 🏗️ Architecture

Design documents and diagrams.

| Document | Description |
|----------|-------------|
| [Overview](./architecture/overview.md) | Landing zone architecture summary |
| [Azure Files Overview](./architecture/azure-files-overview.md) | Azure Files architecture (original scope) |
| [Network Diagram](./architecture/network-diagram.md) | IP addressing and subnet layout |
| [Resource Inventory](./architecture/resource-inventory.md) | Complete list of Azure resources |
| [Mermaid Diagram](./architecture/landing-zone.mmd) | Visual architecture diagram |

---

## 📖 Reference

Background information and reference materials.

| Document | Description |
|----------|-------------|
| [PoC Plan](./reference/poc-plan.md) | Project objectives and evaluation criteria |
| [Deployment Scripts](./reference/deployment-scripts.md) | Script usage and parameters |
| [Subnet/NSG Scoping](./reference/subnet-nsg-scoping.md) | Resource group scoping rules |

---

## 🏛️ BC Government References

Research and reference materials for BC Gov Azure Landing Zones. These documents summarize BC Government Azure patterns, policies, and best practices gathered during PoC planning.

| Topic | Key Documents |
|-------|---------------|
| Landing Zones | [Guardrails Summary](./bcgov-references/BCGov-AzureLandingZone_Guardrails_Summary.md), [Samples Summary](./bcgov-references/BCGov-AzureLandingZoneSamplesSummary.md) |
| Networking | [Networking Summary](./bcgov-references/BCGov-NetworkingSummary.md), [Private DNS & Endpoints](./bcgov-references/BCGov-PrivateDNSandEndpoints.md) |
| IaC & CI/CD | [Best Practices](./bcgov-references/BCGov-IaC_CICD_BestPractices_Summary.md), [Terraform Resources](./bcgov-references/BCGov-TerraformResourcesForAzurePoC.md) |
| Connectivity | [On-Prem Connections](./bcgov-references/BCGov-OnPremConnections.md), [ExpressRoute](./bcgov-references/BCGov-ConnectingOnPremDataCenterResourcesViaExpressRoute.md) |

---

## 🔗 External Resources

- [Azure AI Studio](https://ai.azure.com/)
- [Azure Portal](https://portal.azure.com/)
- [BC Gov Azure Landing Zone Docs](https://github.com/bcgov/azure-lz-samples)

---

## 📝 Contributing

When adding documentation:
1. Use kebab-case for filenames (e.g., `my-new-guide.md`)
2. Place in the appropriate folder (guides/, runbooks/, architecture/, reference/)
3. Update this README index
4. Include a table of contents for longer documents
5. Use consistent heading styles (# for title, ## for sections)
