# Azure Files Proof of Concept

This repository contains documentation and resources for evaluating Azure Files as a cost-effective, performant, and secure replacement for on-premises file storage infrastructure in a government context, specifically for the **BC Government**.

## Project Overview

The BC Government is exploring Azure Files as a solution to address several challenges with current on-premises file storage:

-   **Rising Infrastructure Costs**: Reducing operational expenditures for storage hardware.
-   **Storage Optimization**: Implementing automated tiering strategies for cost-effective data lifecycle management.
-   **Administrative Efficiency**: Decreasing technical overhead while maintaining or improving service levels.
-   **Media File Management**: Better handling of large video/audio files with appropriate archiving capabilities.
-   **Resource Stewardship**: Demonstrating responsible use of taxpayer resources.

## Repository Structure and Key Resources

### Documentation
-   **[ProofOfConceptPlan.md](ProofOfConceptPlan.md)**: Comprehensive plan outlining objectives, evaluation criteria, and timeline.
-   **[ArchitectureOverview.md](ArchitectureOverview.md)**: Detailed architecture design for Azure Files implementation.
-   **[ValidationProcess.md](WorkTracking/OneTimeActivities/ValidationProcess.md)**: Step-by-step guide for validating the end-to-end CI/CD pipeline and implementation process.

### Infrastructure as Code
-   **[terraform/](terraform/)**: Infrastructure code and deployment configurations.
    -   **[README.md](terraform/README.md)**: Setup, usage instructions, and module documentation.
    -   **[environments/](terraform/environments/)**: Environment-specific configurations.
        -   `dev/`: Development environment resources and variables.
        -   `test/`: Test environment resources and variables.
        -   `prod/`: Production environment resources and variables.
    -   **[modules/](terraform/modules/)**: Reusable BC Gov-compliant Terraform modules.
        -   `networking/`: Network components (VNet, Subnet, NSG).
        -   `storage/`: Storage resources (Account, File Share, Blob).
        -   `security/`: Security components (NSG, Firewall).
        -   `dns/`: DNS configuration (Private DNS, Resolver).

### GitHub Actions Workflows
-   **[.github/workflows/](.github/workflows/)**:
    -   **[terraform-common.yml](.github/workflows/terraform-common.yml)**: Reusable Terraform workflow with OIDC authentication.
    -   **[main.yml](.github/workflows/main.yml)**: Environment-specific deployment workflow (e.g., orchestrates `terraform-common.yml`).
    -   **[azure-login-test.yml](.github/workflows/azure-login-test.yml)**: Simple workflow for validating Azure authentication.
    -   **[terraform-validation.yml](.github/workflows/terraform-validation.yml)**: Workflow for validating end-to-end Terraform deployment.

### Resources and Best Practices
-   **[Resources/](Resources/)**:
    -   **[TerraformResourcesForAzurePoC.md](Resources/TerraformResourcesForAzurePoC.md)**: BC Government-specific Terraform guidance.
    -   **[TerraformWithGithubActionsProcess.md](Resources/TerraformWithGithubActionsProcess.md)**: Detailed workflow implementation guide.
    -   **[GitHubActionsResourcesForAzureFilesPoC.md](Resources/GitHubActionsResourcesForAzureFilesPoC.md)**: GitHub Actions setup and OIDC authentication.
    -   **[AzurePipelinesResources.md](Resources/AzurePipelinesResources.md)**: Azure Pipelines integration guide (if applicable, consider if still relevant for GitHub Actions focus).
    -   **[TerraformModuleStructure.md](Resources/TerraformModuleStructure.md)**: Module design and BC Gov requirements.

### Architecture Diagrams
-   **[azure files express route.drawio](azure%20files%20express%20route.drawio)**: Source diagram (draw.io).
-   **[azure files express route.drawio.png](azure%20files%20express%20route.drawio.png)**: Rendered diagram.

## Key Evaluation Areas

1.  **File Access & Management**: Ensuring compatibility with existing workflows, including folder operations and metadata preservation.
2.  **Performance & Latency**: Validating speed for large file transfers and real-time playback scenarios.
3.  **Security & Compliance**: Testing AD integration, permission enforcement, and security controls.
4.  **Backup & Recovery**: Evaluating snapshot capabilities and integration with Azure Backup.
5.  **Tiering & Lifecycle Management**: Testing cost optimization through automated movement between storage tiers.
6.  **Reporting & Monitoring**: Assessing visibility into storage utilization and costs.
7.  **Cost Analysis**: Developing a framework for comprehensive TCO comparison.

## Architecture at a Glance

This PoC implements a hybrid connectivity model with Azure Files accessed via Private Endpoint and optional integration with Azure Blob Storage for tiering:
![azure files express route drawio](https://github.com/user-attachments/assets/e2ef13f6-501c-466a-82ee-654add681e0a)

## Getting Started

Review the [Proof of Concept Plan](ProofOfConceptPlan.md) for an understanding of project objectives and evaluation criteria.

For detailed technical architecture, see the [Architecture Overview](./Architecture/ArchitectureOverview.md).

## Important Rule for Resource Creation

**CRITICAL: DO NOT CREATE ANY RESOURCES IN AZURE WITHOUT EXPLICIT CONSENT AND REVIEW.**

All infrastructure code, scripts, and templates must undergo thorough review and documentation before any resources are deployed to Azure. This ensures:
-   Compliance with BC Government guidelines and security requirements.
-   Cost control and proper resource allocation.
-   Appropriate documentation of all deployed components.
-   Alignment with the project's objectives and architectural design.

## Network Connectivity Options

Multiple connectivity approaches are being evaluated, including:
-   VPN + Private Endpoint (short-term).
-   ExpressRoute + Private Endpoint (long-term).
-   Azure File Sync (hybrid model).

Details on these options are available in the [Network Connectivity Options Analysis](./Architecture/OptionsAnalysis/AzureFilesNetworkConnectivityOptionsAnalysis.md).

## Development Process

This project implements a secure, compliant infrastructure development process using GitHub Actions and Terraform:

### Local Development
1.  Clone repository and set up local environment.
2.  Use Azure CLI authentication for development (`az login`).
3.  Create feature branch for changes.
4.  Test changes locally with `terraform plan`.

### Automated Validation
1.  Push changes to GitHub.
2.  Create Pull Request (targeting `dev` for dev validation, `main` for production).
3.  Automated workflows run:
    -   Terraform validation.
    -   BC Gov policy compliance checks.
    -   Security scanning.
    -   Cost estimation.

### Deployment Process
1.  Pull Request review and approval.
2.  Merge to target branch (e.g., `dev` for dev deployment, `main` for production).
3.  Automated deployment via GitHub Actions:
    -   OIDC authentication to Azure.
    -   Resource creation/update.
    -   Validation checks.

> **Important**: All deployments must follow BC Government security requirements and use approved runners.

For detailed implementation guidance, see:
-   [Terraform Resources Guide](Resources/TerraformResourcesForAzurePoC.md)
-   [GitHub Actions Process](Resources/TerraformWithGithubActionsProcess.md)
-   [BC Gov GitHub Actions Setup](Resources/GitHubActionsResourcesForAzureFilesPoC.md)

## Terraform Development

See the [terraform](./terraform/) directory for infrastructure code. Key aspects:

-   We use Azure CLI authentication for local development (`az login`).
-   No resources are created until explicit `terraform apply` commands are executed (via the pipeline or locally for testing).
-   All sensitive variables are parameterized in accordance with security best practices.
-   A detailed [Deployment Checklist](DEPLOYMENT_CHECKLIST.md) must be completed before any resource creation.

For more information on working with Terraform in this project, see the [Terraform README](terraform/README.md).

## Deployment Workflow Summary (Dev Environment)

The following diagram illustrates the GitHub Actions and Terraform deployment process specifically for the **development environment** in the BC Government context:

```mermaid
sequenceDiagram
    actor Dev as Developer
    participant Git as GitHub Repository<br/>.github/workflows/main.yml
    participant CommonFlow as Common Workflow<br/>.github/workflows/terraform-common.yml
    participant Runner as BC Gov Self-Hosted Runner
    participant AzureAD as Azure Active Directory (Microsoft Entra ID)
    participant KeyVault as Azure Key Vault
    participant TFState as State Management<br/>terraform/backend.tf
    participant TFConfig as Environment Config<br/>terraform/environments/dev/main.tf
    participant Azure as Azure Resource Manager

    Dev->>Git: Push changes to 'dev' branch / Create Pull Request (targeting 'dev')

    Git->>CommonFlow: Call reusable workflow<br/>(e.g., terraform-dev.yml)
    CommonFlow->>Runner: Execute with 'dev' environment context

    Note over Runner,AzureAD: GitHub Actions OIDC Authentication
    Runner->>AzureAD: 1. Request OIDC Token (via GitHub's OIDC Provider)
    AzureAD-->>Runner: 2. Issue Short-Lived OIDC JWT
    Runner->>AzureAD: 3. Use azure/login@v1 action:<br/>Exchange OIDC JWT for Azure AD Access Token<br/>(using client-id, tenant-id, subscription-id from GitHub Secrets)
    AzureAD-->>Runner: 4. Provide Azure AD Access Token<br/>(authenticated as Service Principal for Dev)

    opt Optional: Retrieve secrets from Key Vault
        Note over Runner,KeyVault: Retrieve Sensitive Configuration (if any)
        Runner->>KeyVault: 5. Authenticate with Azure AD Access Token<br/>and fetch secrets/variables (e.g., API keys, DB connection strings)
        KeyVault-->>Runner: 6. Provide fetched secrets
    end

    Note over Runner,TFState: Initialize Terraform Backend
    Runner->>TFState: 7. terraform init<br/>(backend.tf - uses authenticated Azure identity for storage access)
    TFState-->>Runner: 8. State Backend Ready

    alt Pull Request (Plan Only)
        Note over Runner,TFConfig: Generate Terraform Plan
        Runner->>TFConfig: 9. terraform plan<br/>(main.tf, terraform.tfvars - uses authenticated Azure identity and retrieved secrets)
        TFConfig->>Azure: 10. Validate against BC Gov policies / Check Azure resources
        Azure-->>TFConfig: 11. Policy validation / Resource status
        TFConfig-->>Runner: 12. Plan output (proposed changes)
        Runner-->>Git: 13. Post plan as PR comment
    else Push to 'dev' (Apply Changes)
        Note over Runner,TFConfig: Apply Terraform Changes
        Runner->>TFConfig: 9. terraform apply<br/>(main.tf, terraform.tfvars - uses authenticated Azure identity and retrieved secrets)
        TFConfig->>Azure: 10. Create/Update Azure Resources via Azure ARM API
        Azure-->>TFConfig: 11. Resource Status / API Response
        TFConfig-->>Runner: 12. Apply Complete (resources provisioned/updated)
        Runner-->>CommonFlow: 13. Workflow Results / Success/Failure
        CommonFlow-->>Git: 14. Update branch status (e.g., green checkmark)
    end