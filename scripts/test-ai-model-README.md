# AI Model Testing Script

This script provides a simple "Hello World" test for Azure AI Foundry models and endpoints.

## Prerequisites

1. **Azure CLI installed and logged in**: `az login`
2. **Azure AI Foundry workspace deployed** (from this PoC)
3. **Model deployed to an endpoint** (optional - can just list available endpoints)

## Usage Examples

### Test AI Foundry Workspace (List available endpoints)

```powershell
.\test-ai-model.ps1 -WorkspaceName "foundry-azurefiles-poc" -ResourceGroup "your-resource-group"
```

### Test a Specific Deployed Endpoint

```powershell
.\test-ai-model.ps1 -WorkspaceName "foundry-azurefiles-poc" -ResourceGroup "your-resource-group" -EndpointName "my-gpt-endpoint"
```

### Test with Azure OpenAI (if using direct OpenAI instead of Foundry)

```powershell
.\test-ai-model.ps1 -WorkspaceName "foundry-azurefiles-poc" -ResourceGroup "your-resource-group" -UseAzureOpenAI -ModelName "gpt-4o-mini"
```

### Test with Specific Subscription

```powershell
.\test-ai-model.ps1 -WorkspaceName "foundry-azurefiles-poc" -ResourceGroup "your-resource-group" -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

## What the Test Does

1. **Verifies Azure CLI authentication**
2. **Checks workspace existence**
3. **Lists available endpoints** (if no endpoint specified)
4. **Makes a simple inference call** with prompt: "Hello! Please respond with a simple greeting and tell me what AI model you are."
5. **Displays the AI model's response**

## Expected Output

```
Connected to Azure subscription: My Subscription Name

Testing Azure AI Foundry workspace: foundry-azurefiles-poc
Found AI Foundry workspace: foundry-azurefiles-poc
Location: canadaeast

Testing deployed endpoint: my-gpt-endpoint
Found endpoint: my-gpt-endpoint
Provisioning state: Succeeded

Response from endpoint my-gpt-endpoint:
Hello! I'm Claude, an AI assistant created by Anthropic. How can I help you today?

AI Model test completed successfully! 🎉
```

## Troubleshooting

- **"Not logged in to Azure CLI"**: Run `az login`
- **"Workspace not found"**: Check resource group name and workspace name
- **"Endpoint not found"**: Deploy a model first in Azure AI Studio
- **"No API key available"**: Check endpoint authentication settings

## Next Steps

After successful testing:
1. Deploy more complex models in Azure AI Studio
2. Test with your actual use cases and prompts
3. Integrate with your applications using the REST APIs
4. Monitor usage and performance in Azure Monitor