# Ad-hoc Data Upload to Blob Storage

This guide explains how to securely upload datasets or model artifacts to an Azure Storage blob container from a local environment. Since the landing zone architecture prioritizes **zero-trust networking** (private endpoints), this process involves temporarily allowing your local IP address to bypass the public network firewall for the duration of the upload.

## High level steps

1. Setup storage account
2. Setup a blob container
3. enable public network access on the storage account 
4. public network access: Enable public access
5. Public network access scope:  enable from selected networks
6. IPv4 addresses:  allow select public IP addresses to access your resource.  Provide the IP addresses
8. On blob container create SAS token that allows read/write etc to that container 
9. Azcopy command 

## Prerequisites

- **Storage Account:** Must be deployed (see [Deployment Guide](./deployment-guide.md)).
- **AzCopy:** Installed on your local machine. [Download AzCopy here](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-v10).
- **Permissions:** Storage Blob Data Contributor or Owner role on the storage account.

## Step 1: Configure Networking (Temporary Access)

To upload from outside the VNet, you must temporarily whitelist your local IP address.

1. Navigate to your **Storage Account** in the Azure Portal.
2. Select **Networking** under the Security + networking section.
3. Under **Public network access**, ensure it is set to **Enabled from selected virtual networks and IP addresses**.
4. In the **Firewall** section:
   - Check the box **Add your client IP address** (this adds your current public IP).
   - Alternatively, manually enter your IPv4 address.
5. Click **Save** and wait ~30 seconds for the firewall rules to propagate.

## Step 2: Create a Blob Container

If you haven't already created a container:

1. Select **Containers** under Data storage.
2. Click **+ Container**.
3. Name your container (e.g., `datasets` or `model-artifacts`).
4. Keep the Public access level as **Private (no anonymous access)**.
5. Click **Create**.

## Step 3: Generate a SAS Token

A Shared Access Signature (SAS) provides secure, delegated access to the container for the `azcopy` command.

1. Enter the container you just created.
2. Select **Shared access tokens** from the left menu.
3. Configure the token permissions:
   - **Permissions:** Read, Write, List.
   - **Expiry:** Set to a short duration (e.g., 2 hours).
4. Click **Generate SAS token and URL**.
5. Copy the **Blob SAS URL**. This URL includes the SAS token as a query parameter.

## Step 4: Upload Files using AzCopy

Open your terminal (PowerShell or Bash) and run the `azcopy` command:

```bash
# Upload a single file
azcopy copy "C:\path\to\your\localfile.txt" "https://<storageaccount>.blob.core.windows.net/<container>/<sasToken>"

# Upload an entire directory
azcopy copy "C:\path\to\your\folder\*" "https://<storageaccount>.blob.core.windows.net/<container>/<sasToken>" --recursive
```

> [!TIP]
> Use the `-V` flag for verbose output if you encounter connectivity issues.

## Step 5: Restore Security Guardrails

Once the upload is complete, you should remove the public network exception to maintain the landing zone's security posture.

1. Return to the **Storage Account** -> **Networking** tab.
2. Remove your local IP address from the firewall list.
3. Set **Public network access** to **Disabled** (if you are only using private endpoints) or keep it on **Selected networks** but with an empty list.
4. Click **Save**.

---

**Next Steps:**
- Verify the files are accessible from your [Virtual Machine](./deployment-guide.md#phase-3-compute-resources) via the private endpoint.
- Refer to the [AI Model Testing Guide](./ai-model-testing.md) for using these files in your AI workloads.