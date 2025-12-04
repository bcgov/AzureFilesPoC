# Azure AI Services Guidance (BC Gov)

_Last updated: November 4, 2025_

## Overview
Many ministry teams use Azure AI services to build intelligent applications. AI/ML technologies are rapidly evolving. This document summarizes best practices, region availability, deployment considerations, compliance, and monitoring for Azure AI in BC Gov.

## Azure OpenAI Best Practices
- Review the [Microsoft Azure OpenAI best practices blog post](https://techcommunity.microsoft.com/t5/ai-cognitive-services-blog/azure-openai-best-practices-a-quick-reference-guide-to-optimize/ba-p/4048372) for architecture, security, governance, networking, and more.
- Use the Azure OpenAI review checklist (180+ best practices) for Governance, Operations, Networking, Identity, Cost Management, and BCDR.
- Use the [Azure OpenAI PTU Calculator](https://oai.azure.com/ptu-calculator) to optimize costs and size Provisioned Throughput Units (PTUs).

## Region Availability
- Azure AI Foundry (Azure AI Studio) is available in Canada regions, but not all models/services are available in Canada.
- **Canada East**: Most Azure AI models are only available here. Current Landing Zones do not include connectivity to Canada East.
- Always check region/model availability before starting development.

## Common Azure AI Services Used
- Azure OpenAI
- AI Search
- Document Intelligence

_Leverage experience from other ministry teams to avoid common pitfalls._

## Deploying Models & Private Networking
- For private-only AI services, deploy a VM in your Azure VNet to host models securely.
- Use Azure Bastion for secure access to VMs in private networks.
- See the Tools > Azure Bastion page for deployment examples (Terraform module available).

## Azure OpenAI & Private DNS

### Troubleshooting: Missing DNS A-Record for Azure OpenAI
When working with Azure OpenAI, you may need to create a Private Endpoint to resolve the service endpoints. In several cases, the DNS A-Record for the Azure OpenAI service is not created properly in the Private DNS Zone. This can cause issues with the service not being able to resolve the endpoint.

**If you encounter this issue:**
- Open a support ticket with the Public Cloud support team to investigate and resolve the DNS record problem.

- Configure services securely from the outset to avoid policy enforcement issues.

## Monitoring AI
- Use the Azure Monitor Workbook for centralized monitoring of AI services (usage, performance, health).
- See [Azure OpenAI Insights: Monitoring AI with Confidence](https://techcommunity.microsoft.com/t5/ai-cognitive-services-blog/azure-openai-insights-monitoring-ai-with-confidence/ba-p/4048373) for more info.

---

For more details, see the [BC Gov Public Cloud TechDocs: Azure AI Services](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/azure-services/azure-ai/).
