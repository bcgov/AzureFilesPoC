# Windows instructions to create SSH key

## 1. Open PowerShell
Press `Win + X`, then select **Windows PowerShell** or **Terminal**.

## 2. Generate a new SSH key pair
Run the following command (replace your email if desired):

```powershell
ssh-keygen -t rsa -b 4096 -C "your.email@example.com"
```

- When prompted for a file location, press **Enter** to accept the default (`C:\Users\<YourUser>\.ssh\id_rsa`).
- Optionally, set a passphrase for extra security, or press **Enter** to leave it empty.

## 3. Locate your SSH public key
Your public key will be saved as:

```
C:\Users\<YourUser>\.ssh\id_rsa.pub
```

## 4. Copy the public key contents
Run this command to display your public key:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
```

Copy the entire output. You will paste this value when prompted by the VM deployment script.

---
**Note:** Never share your private key (`id_rsa`). Only the `.pub` file is safe to share for authentication.
