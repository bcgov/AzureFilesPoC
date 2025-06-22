# GitHub Actions Secrets and Variables Checklist

This file lists all the secrets and variables you need to add to your repository for the Azure Files PoC Terraform CI/CD workflow. Mark each one off as you add it in GitHub.

**Add these in Settings > Secrets and variables > Actions.**

## Secrets (Sensitive)
- [X] AZURE_CLIENT_ID
- [X] AZURE_TENANT_ID
- [X] AZURE_SUBSCRIPTION_ID
- [X] DEV_RESOURCE_GROUP_NAME
- [X] DEV_VNET_NAME
- [X] DEV_VNET_RESOURCE_GROUP
- [X] AZURE_SUBSCRIPTION_NAME
- [X] DEV_VNET_ID
- [X] DEV_SUBSCRIPTION_NAME
- [X] DEV_SUBSCRIPTION_ID

## Variables (Non-sensitive)
- [X] AZURE_LOCATION (e.g., canadacentral)
- [X] DEV_STORAGE_ACCOUNT_NAME (e.g., stexampledev01)
- [X] DEV_FILE_SHARE_NAME (e.g., fspoc)
- [X] DEV_FILE_SHARE_QUOTA_GB (e.g., 5)
- [X] DEV_VNET_ADDRESS_SPACE
- [X] DEV_DNS_SERVERS
- [X] DEV_SUBNET_NAME
- [X] DEV_SUBNET_ADDRESS_PREFIXES
- [X] DEV_VNET_RESOURCE_GROUP

---

**Instructions:**
- Add each secret/variable in the GitHub UI.
- Fill in the value for each (use your real Azure/project values).
- Check off each item here as you go.

*This file is for your reference only and should remain in .gitignore.*
