# Test Azure AI Foundry Model Inference
# Simple "Hello World" test for deployed AI models

param(
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "",

    [Parameter(Mandatory=$false)]
    [string]$ModelName = "gpt-4o-mini",  # Default to a small/fast model

    [Parameter(Mandatory=$false)]
    [string]$EndpointName = "",  # If testing a deployed endpoint

    [Parameter(Mandatory=$false)]
    [switch]$UseAzureOpenAI  # Use Azure OpenAI instead of AI Foundry
)

# Set subscription if provided
if ($SubscriptionId) {
    az account set --subscription $SubscriptionId
}

# Verify Azure CLI login
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Error "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
}

Write-Host "Connected to Azure subscription: $($account.name)" -ForegroundColor Green

# Test message
$testPrompt = "Hello! Please respond with a simple greeting and tell me what AI model you are."

if ($UseAzureOpenAI) {
    # Test using Azure OpenAI directly
    Write-Host "`nTesting Azure OpenAI model: $ModelName" -ForegroundColor Cyan

    # Get Azure OpenAI resource info
    $openaiResources = az cognitiveservices account list --resource-group $ResourceGroup 2>$null | ConvertFrom-Json

    if (-not $openaiResources) {
        Write-Error "No Azure OpenAI resources found in resource group $ResourceGroup"
        exit 1
    }

    $openaiResource = $openaiResources | Where-Object { $_.kind -eq "OpenAI" } | Select-Object -First 1

    if (-not $openaiResource) {
        Write-Error "No Azure OpenAI resource found in resource group $ResourceGroup"
        exit 1
    }

    Write-Host "Found Azure OpenAI resource: $($openaiResource.name)" -ForegroundColor Green

    # Get API key from Key Vault (assuming it's stored there)
    $keyVaultName = "kv-$($WorkspaceName.ToLower())"
    $apiKey = az keyvault secret show --vault-name $keyVaultName --name "openai-api-key" 2>$null | ConvertFrom-Json

    if (-not $apiKey) {
        Write-Error "Could not retrieve API key from Key Vault. Make sure the secret 'openai-api-key' exists."
        exit 1
    }

    # Make API call to Azure OpenAI
    $endpoint = "https://$($openaiResource.name).openai.azure.com/"
    $headers = @{
        "api-key" = $apiKey.value
        "Content-Type" = "application/json"
    }

    $body = @{
        "messages" = @(
            @{
                "role" = "user"
                "content" = $testPrompt
            }
        )
        "max_tokens" = 100
        "temperature" = 0.7
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri "$endpoint/openai/deployments/$ModelName/chat/completions?api-version=2024-02-15-preview" -Method Post -Headers $headers -Body $body
        Write-Host "`nResponse from $ModelName :" -ForegroundColor Yellow
        Write-Host $response.choices[0].message.content -ForegroundColor White
    }
    catch {
        Write-Error "Failed to call Azure OpenAI API: $($_.Exception.Message)"
        exit 1
    }

} else {
    # Test using Azure AI Foundry/ML Studio
    Write-Host "`nTesting Azure AI Foundry workspace: $WorkspaceName" -ForegroundColor Cyan

    # Check if workspace exists
    $workspace = az ml workspace show --name $WorkspaceName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json

    if (-not $workspace) {
        Write-Error "Azure AI Foundry workspace '$WorkspaceName' not found in resource group '$ResourceGroup'"
        exit 1
    }

    Write-Host "Found AI Foundry workspace: $($workspace.name)" -ForegroundColor Green
    Write-Host "Location: $($workspace.location)" -ForegroundColor Green

    if ($EndpointName) {
        # Test a deployed endpoint
        Write-Host "`nTesting deployed endpoint: $EndpointName" -ForegroundColor Cyan

        $endpoint = az ml online-endpoint show --name $EndpointName --workspace-name $WorkspaceName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json

        if (-not $endpoint) {
            Write-Error "Endpoint '$EndpointName' not found in workspace '$WorkspaceName'"
            exit 1
        }

        Write-Host "Found endpoint: $($endpoint.name)" -ForegroundColor Green
        Write-Host "Provisioning state: $($endpoint.provisioning_state)" -ForegroundColor Green

        # Test the endpoint with a simple inference call
        $scoringUri = $endpoint.scoring_uri
        $apiKey = $endpoint.keys.primary_key

        if (-not $apiKey) {
            Write-Error "No API key available for endpoint. Make sure authentication is properly configured."
            exit 1
        }

        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }

        # Sample payload for chat completion (adjust based on your model)
        $body = @{
            "messages" = @(
                @{
                    "role" = "user"
                    "content" = $testPrompt
                }
            )
            "max_tokens" = 100
            "temperature" = 0.7
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $scoringUri -Method Post -Headers $headers -Body $body
            Write-Host "`nResponse from endpoint $EndpointName :" -ForegroundColor Yellow
            Write-Host $response.choices[0].message.content -ForegroundColor White
        }
        catch {
            Write-Error "Failed to call endpoint API: $($_.Exception.Message)"
            exit 1
        }

    } else {
        # Just show workspace info and available models/endpoints
        Write-Host "`nWorkspace Details:" -ForegroundColor Cyan
        Write-Host "- Name: $($workspace.name)"
        Write-Host "- Location: $($workspace.location)"
        Write-Host "- Resource Group: $($workspace.resourceGroup)"
        Write-Host "- Workspace ID: $($workspace.workspaceId)"

        Write-Host "`nAvailable Online Endpoints:" -ForegroundColor Cyan
        $endpoints = az ml online-endpoint list --workspace-name $WorkspaceName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json

        if ($endpoints) {
            foreach ($endpoint in $endpoints) {
                Write-Host "- $($endpoint.name) (State: $($endpoint.provisioning_state))"
            }
        } else {
            Write-Host "No online endpoints found. Deploy a model first using Azure AI Studio."
        }

        Write-Host "`nTo test a specific endpoint, run:" -ForegroundColor Cyan
        Write-Host ".\test-ai-model.ps1 -WorkspaceName $WorkspaceName -ResourceGroup $ResourceGroup -EndpointName <endpoint-name>"
    }
}

Write-Host "`nAI Model test completed successfully! 🎉" -ForegroundColor Green