# Infrastructure-as-Code (IaC) and CI/CD in BC Gov Azure Landing Zones

_Last updated: June 27, 2025_

**Source:** [BC Gov Azure IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)

---

## Key Highlights & Best Practices

### 1. Cross-Subscription Deployments
- If deploying GitHub self-hosted runners or Azure DevOps Managed DevOps Pools into a different subscription than your main resources, you must submit a firewall request to the Public Cloud team to allow cross-subscription access.

### 2. Terraform and Resource Tags
- Azure Verified Modules (AVM) for CICD Agents, Runners, and Managed DevOps Pools may not be aware of all resource tags.
- To prevent Terraform from removing tags, add a `lifecycle` block with `ignore_changes` for tags in your resource definitions.

### 3. Subnet Creation with NSG Requirement
- Azure Policy requires every subnet to have an associated Network Security Group (NSG).
- **Do not use** `azurerm_subnet` to create subnets with NSGs in a single step.
- **Use** `azapi_resource` from the AzAPI Terraform Provider to create subnets with NSGs in one operation.
- See the [GitHub Issue](https://github.com/Azure/terraform-provider-azapi/issues/503) for more details.

### 4. Private Endpoints and DNS
- Azure Policy will automatically associate Private Endpoints with the appropriate Private DNS Zone and create DNS records.
- Terraform will detect these changes as out-of-band and may try to remove the association.
- Add a `lifecycle` block with `ignore_changes = [private_dns_zone_group]` to your `azurerm_private_endpoint` resources to prevent Terraform from removing these policy-created associations.

### 5. AzAPI Provider Limitations
- When deleting an `azapi_update_resource`, no operation is performed and properties may remain unchanged.
- To revert changes, restore the properties before deleting the resource.

### 6. GitHub Actions CI/CD
- Use OpenID Connect (OIDC) authentication for GitHub Actions to securely access Azure subscriptions.
- Configure Entra ID Application, Service Principal, and federated credentials.
- Use the `azure/login` action in your workflows to exchange the OIDC token for an Azure access token.
- Self-hosted runners on Azure are required for accessing data storage and database services from GitHub Actions.

### 7. GitHub Self-Hosted Runners on Azure
- Use the Azure Verified Module (AVM) for CICD Agents and Runners.
- See the [azure-lz-samples](https://github.com/bcgov/azure-lz-samples) repository for sample Terraform code and pre-requisites.

### 8. Azure Pipelines and Managed DevOps Pools
- Use Azure DevOps Workload identity federation (OIDC) for authentication.
- Use the Azure Verified Module for Managed DevOps Pools.
- See the [azure-lz-samples](https://github.com/bcgov/azure-lz-samples) repository for sample code and pre-requisites.

---

## References
- [BC Gov Azure IaC and CI/CD Best Practices](https://developer.gov.bc.ca/docs/default/component/public-cloud-techdocs/azure/best-practices/iac-and-ci-cd/)
- [GitHub Issue: AzAPI Subnet Association](https://github.com/Azure/terraform-provider-azapi/issues/503)
- [azure-lz-samples GitHub Repository](https://github.com/bcgov/azure-lz-samples)

---

**Summary:**
- Always follow BC Gov best practices for cross-subscription deployments, subnet/NSG creation, and private endpoint DNS integration.
- Use AzAPI for subnet creation with NSGs, and lifecycle ignore_changes for tags and DNS associations.
- Use OIDC for secure CI/CD authentication.
- Refer to the official documentation and sample repositories for up-to-date guidance and code examples.
