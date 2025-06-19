# Azure Files Proof of Concept

This repository contains documentation and resources for evaluating Azure Files as a cost-effective, performant, and secure replacement for on-premises file storage infrastructure in a government context.

## Project Overview

The BC Government is exploring Azure Files as a solution to address several challenges with current on-premises file storage:

- **Rising Infrastructure Costs**: Reducing operational expenditures for storage hardware
- **Storage Optimization**: Implementing automated tiering strategies for cost-effective data lifecycle management
- **Administrative Efficiency**: Decreasing technical overhead while maintaining or improving service levels
- **Media File Management**: Better handling of large video/audio files with appropriate archiving capabilities
- **Resource Stewardship**: Demonstrating responsible use of taxpayer resources

## Repository Contents

- **[ProofOfConceptPlan.md](ProofOfConceptPlan.md)**: Comprehensive plan outlining problem statement, objectives, evaluation criteria, test scenarios, and timeline
- **[ArchitectureOverview.md](./Architecture/ArchitectureOverview.md)**: Detailed architecture design showcasing integration between on-premises environments and Azure Files via ExpressRoute and Private Endpoints
- **[AzureFilesNetworkConnectivityOptionsAnalysis.md](./Architecture//OptionsAnalysis/AzureFilesNetworkConnectivityOptionsAnalysis.mdAzureFilesNetworkConnectivityOptionsAnalysis.md)**: Analysis of different connectivity approaches for accessing Azure Files securely
- **[azure files express route.drawio](./Architecture/azure%20files%20express%20route.drawio)**: Source file for the architecture diagram (editable in draw.io)
- **[azure files express route.drawio.png](./Architecture/azure%20files%20express%20route.drawio.png)**: Rendered architecture diagram

## Key Evaluation Areas

1. **File Access & Management**: Ensuring compatibility with existing workflows, including folder operations and metadata preservation
2. **Performance & Latency**: Validating speed for large file transfers and real-time playback scenarios
3. **Security & Compliance**: Testing AD integration, permission enforcement, and security controls
4. **Backup & Recovery**: Evaluating snapshot capabilities and integration with Azure Backup
5. **Tiering & Lifecycle Management**: Testing cost optimization through automated movement between storage tiers
6. **Reporting & Monitoring**: Assessing visibility into storage utilization and costs
7. **Cost Analysis**: Developing a framework for comprehensive TCO comparison

## Architecture at a Glance

This PoC implements a hybrid connectivity model with Azure Files accessed via Private Endpoint and optional integration with Azure Blob Storage for tiering:
![azure files express route drawio](https://github.com/user-attachments/assets/e2ef13f6-501c-466a-82ee-654add681e0a)

## Getting Started

Review the [Proof of Concept Plan](ProofOfConceptPlan.md) for an understanding of project objectives and evaluation criteria.

For detailed technical architecture, see the [Architecture Overview](./Architecture/ArchitectureOverview.md).

## Important Rule for Resource Creation

**CRITICAL: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW.**

All infrastructure code, scripts, and templates must undergo thorough review and documentation before any resources are deployed to Azure. This ensures:
- Compliance with BC Government guidelines and security requirements
- Cost control and proper resource allocation
- Appropriate documentation of all deployed components
- Alignment with the project's objectives and architectural design

## Network Connectivity Options

Multiple connectivity approaches are being evaluated, including:
- VPN + Private Endpoint (short-term)
- ExpressRoute + Private Endpoint (long-term)
- Azure File Sync (hybrid model)

Details on these options are available in the [Network Connectivity Options Analysis](./Architecture//OptionsAnalysis/AzureFilesNetworkConnectivityOptionsAnalysis.md).

## Development Workflow

This project follows a deliberate, staged approach to infrastructure development:

### Phase 1: Local Terraform Development (Current Phase)
- Develop and test all Terraform scripts locally using Azure CLI authentication
- Validate infrastructure code without creating actual resources (`terraform plan`)
- Document all planned resources and configurations thoroughly
- Review code for security, compliance, and cost optimization
- Ensure all code is version-controlled in this repository

### Phase 2: Manual Validation
- Execute carefully controlled manual deployments of critical components
- Validate functionality, security, and performance against evaluation criteria
- Document findings and make necessary adjustments to Terraform code
- Perform controlled teardown of resources when testing is complete

### Phase 3: GitHub Actions Integration (Future)
- Only after successful local testing and validation
- Configure GitHub Actions workflows for automated testing and deployment
- Implement proper security controls for service principal authentication
- Establish approval gates for any resource creation

This phased approach ensures that all infrastructure is thoroughly tested and validated before introducing the additional complexity of CI/CD pipelines.

> **Current Status**: We are in Phase 1, focusing on local Terraform script development and documentation.

## Terraform Development

See the [terraform](./terraform/) directory for infrastructure code. Key aspects:

- We use Azure CLI authentication for local development (`az login`)
- No resources are created until explicit `terraform apply` commands are executed
- All sensitive variables are parameterized in accordance with security best practices
- A detailed [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) must be completed before any resource creation

For more information on working with Terraform in this project, see the [Terraform README](terraform/README.md).

## License

This project documentation is property of the BC Government and subject to applicable government information policies.
