# VM Update & Maintenance Guide

Keeping your VM up to date is critical for security and stability. This guide covers how to check for, apply, and verify updates on your Ubuntu VM.

## Why Update?
- Security patches protect against vulnerabilities
- Stability and performance improvements
- Required for compliance and best practices

## How to Check for Updates
After connecting to your VM (via Bastion or SSH):

```bash
sudo apt update
apt list --upgradable
```
- This will list all available updates.

## How to Apply Updates
To install all available updates:

```bash
sudo apt update && sudo apt upgrade -y
```
- The `-y` flag automatically confirms prompts.

## Reboot if Required
If you see `*** System restart required ***` or are prompted after updates:

```bash
sudo reboot
```
- This will restart your VM and apply kernel or system-level updates.

## Best Practices
- Run updates regularly (at least monthly)
- Always update before running critical workloads
- Reboot after major updates
- Monitor for update notifications on login

## Reference
- [Ubuntu Security Notices](https://ubuntu.com/security/notices)
- [apt update/upgrade documentation](https://help.ubuntu.com/community/AptGet/Howto)

## Example Workflow
1. Connect to VM via Bastion:
   ```bash
   az network bastion ssh --name ...
   ```
2. Check for updates:
   ```bash
   sudo apt update
   apt list --upgradable
   ```
3. Apply updates:
   ```bash
   sudo apt upgrade -y
   ```
4. Reboot if required:
   ```bash
   sudo reboot
   ```

---

**Always shut down your VM when finished to avoid extra billing!**
See [VM Shutdown](./vm-shutdown.md) for details.
