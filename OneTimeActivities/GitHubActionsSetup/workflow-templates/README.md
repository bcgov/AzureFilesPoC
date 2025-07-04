# GitHub Actions Workflow Templates

This directory contains template workflows that you can use as starting points for your GitHub Actions workflows.

## Available Templates

### 1. azure-login-test.yml
A simple workflow to test Azure authentication using OIDC. This is useful for validating that your GitHub secrets and Azure service principal are configured correctly.

**Features:**
- Manual trigger only (`workflow_dispatch`)
- Uses OIDC authentication
- Shows Azure account information
- Lists resource groups to verify permissions

**Usage:**
1. Copy to `.github/workflows/azure-login-test.yml`
2. Ensure you have the required secrets configured:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
3. Run manually from the Actions tab

### 2. terraform-cicd.yml
A complete Terraform CI/CD pipeline with plan and apply capabilities.

**Features:**
- Manual trigger with environment selection
- Automatic trigger on pull requests
- Terraform plan and apply
- Dynamic terraform.tfvars generation from GitHub secrets/variables
- Support for multiple environments (dev, test, prod)

**Usage:**
1. Copy to `.github/workflows/terraform-cicd.yml`
2. Configure all required GitHub secrets and variables (see the tfvars generation section)
3. Set up GitHub environments for approval gates

### 3. self-hosted-runner.yml
A workflow that demonstrates how to use self-hosted runners for data plane operations.

**Features:**
- Runs on self-hosted runners
- Environment selection
- Azure authentication and data plane access
- Example of Azure Files operations that require network access

**Usage:**
1. Set up a self-hosted runner first (see [SelfHostedRunnerSetup](../../SelfHostedRunnerSetup/README.md))
2. Copy to `.github/workflows/self-hosted-runner.yml`
3. Modify the Azure Files operations to match your specific use case

## Required Secrets and Variables

### Secrets
These should be configured in your GitHub repository settings under "Secrets and variables" -> "Actions":

- `AZURE_CLIENT_ID`: Service principal client ID
- `AZURE_TENANT_ID`: Azure tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `ADMIN_SSH_KEY_PUBLIC`: Public SSH key for VM access
- `SERVICE_PRINCIPAL_ID`: Service principal object ID

### Variables
These should be configured as repository or environment variables:

#### Environment Configuration
- `AZURE_LOCATION`: Azure region (e.g., "Canada Central")
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

#### Service Principal
- `SERVICE_PRINCIPAL_ID`: Service principal object ID

#### Networking (Landing Zone)
- `VNET_NAME`: Virtual network name
- `VNET_RESOURCE_GROUP`: VNet resource group
- `VNET_ADDRESS_SPACE`: VNet address space (JSON array)
- `VNET_DNS_SERVERS`: DNS servers (JSON array)
- `VNET_ID`: VNet resource ID
- `DNS_SERVERS`: DNS servers (JSON array)

#### Resource Groups
- `RESOURCE_GROUP_NAME`: Main resource group name
- `RESOURCE_GROUP`: Resource group name
- `RESOURCE_ID`: Resource group ID

#### Terraform State
- `TFSTATE_CONTAINER`: Storage container for Terraform state
- `TFSTATE_RG`: Resource group for Terraform state storage
- `TFSTATE_SA`: Storage account for Terraform state

#### Storage
- `STORAGE_ACCOUNT_NAME`: Storage account name
- `FILE_SHARE_NAME`: File share name
- `FILE_SHARE_QUOTA_GB`: File share quota in GB

#### Network Security Groups
- `NETWORK_SECURITY_GROUP`: Main NSG name
- `BASTION_NETWORK_SECURITY_GROUP`: Bastion NSG name
- `RUNNER_NETWORK_SECURITY_GROUP`: Runner NSG name
- `STORAGE_NETWORK_SECURITY_GROUP`: Storage NSG name

#### Subnets
- `STORAGE_SUBNET_NAME`: Storage subnet name
- `STORAGE_SUBNET_ADDRESS_PREFIX`: Storage subnet address prefix (JSON array)
- `SUBNET_NAME`: Main subnet name
- `SUBNET_ADDRESS_PREFIXES`: Subnet address prefixes (JSON array)
- `BASTION_SUBNET_NAME`: Bastion subnet name
- `BASTION_ADDRESS_PREFIX`: Bastion subnet address prefix (JSON array)
- `RUNNER_SUBNET_NAME`: Runner subnet name
- `RUNNER_VNET_ADDRESS_SPACE`: Runner VNet address space (JSON array)

#### Gateway
- `GATEWAY_SUBNET_NAME`: Gateway subnet name
- `GATEWAY_SUBNET_ADDRESS_PREFIX`: Gateway subnet address prefix (JSON array)
- `VNG_NAME`: Virtual network gateway name
- `VNG_PUBLIC_IP_NAME`: VNG public IP name
- `VNG_SKU`: VNG SKU
- `VNG_TYPE`: VNG type
- `VNG_VPN_TYPE`: VPN type

#### Bastion
- `BASTION_NAME`: Bastion host name
- `BASTION_PUBLIC_IP_NAME`: Bastion public IP name

#### GitHub Runner VM
- `RUNNER_VM_NAME`: Runner VM name
- `RUNNER_VM_IP_ADDRESS`: Runner VM IP address
- `RUNNER_VM_ADMIN_USERNAME`: VM admin username
- `RUNNER_VM_SIZE`: VM size

#### Security
- `MY_GITHUB_ACTIONS_SPN_OBJECT_ID`: Service principal object ID
- `MY_HOME_IP_ADDRESS`: Your home IP address

#### Tagging
- `COMMON_TAGS`: Common tags for resources (JSON object)

## Customization

### Modifying Templates
1. Copy the template to your `.github/workflows/` directory
2. Rename the file to match your use case
3. Update the workflow name and triggers as needed
4. Modify the steps to match your specific requirements

### Adding Environment-Specific Logic
Use GitHub's environment feature to:
- Require manual approval for production deployments
- Set environment-specific variables
- Configure different secrets per environment

### Example Environment Configuration
```yaml
environment: 
  name: production
  url: https://your-app.com
```

## Best Practices

1. **Start Simple**: Begin with the `azure-login-test.yml` template to validate authentication
2. **Use Environments**: Set up GitHub environments for approval gates on sensitive deployments
3. **Validate Changes**: Always run `terraform plan` before `terraform apply`
4. **Monitor Workflows**: Set up notifications for workflow failures
5. **Use Self-Hosted Runners**: For data plane operations that require network access to Azure services

## Troubleshooting

If workflows fail:
1. Check the workflow run logs for specific error messages
2. Verify all required secrets and variables are configured
3. Ensure the service principal has the necessary permissions
4. For network-related issues, verify NSG rules and subnet configurations

For more detailed troubleshooting, see the [CICD Troubleshooting Guide](../../../terraform/environments/cicd/TROUBLESHOOTING.md).
