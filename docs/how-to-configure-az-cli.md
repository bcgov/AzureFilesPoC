# How to Configure Azure CLI and PowerShell for Azure

## Install Azure CLI

Download and install the Azure CLI from:
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

---

## Install Azure PowerShell Modules

To use PowerShell with Azure (for commands like `Get-AzResource`), you must install the Az modules:

```powershell
Install-Module -Name Az -Scope CurrentUser -Force
Import-Module Az
```

If you only need networking commands, you can install just the network module:

```powershell
Install-Module -Name Az.Network -Scope CurrentUser -Force
Import-Module Az.Network
```

---

## Logging in to Azure (Device Authentication)

If you are in a restricted environment or the browser pop-up does not appear, use device authentication:

```powershell
Connect-AzAccount -UseDeviceAuthentication
```

You will see output like:

```
WARNING: You may need to login again after updating "EnableLoginByWam".
Please select the account you want to login with.

[Login to Azure] To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code BSDTBDKC4 to authenticate.
Retrieving subscriptions for the selection...
```

Open the provided URL in your browser, enter the code, and complete the login process.

---

## Troubleshooting
- If you see errors like `The term 'Get-AzNetworkInterface' is not recognized`, ensure the Az module is installed and imported.
- If login does not open a browser, always try `-UseDeviceAuthentication`.
- If you have multiple subscriptions, you can select the active one after login.

---

## Useful Commands

- List all resources in a resource group:
  ```powershell
  Get-AzResource -ResourceGroupName <your-resource-group>
  ```
- Remove a resource group (must be empty):
  ```powershell
  Remove-AzResourceGroup -Name <your-resource-group>
  ```
