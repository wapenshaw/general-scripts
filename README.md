# General Scripts I use on a Windows 11 install

### Should also work for Windows 10 and other similar Editions of Windows

---

## 1. [Windows Package Upgrader Script](winget-upgrade-all-except.ps1)

### Description

This PowerShell script checks if it is running with administrator privileges. If not, it prompts the user to continue execution. It retrieves a list of upgradable packages using `winget upgrade` command, parses the output to identify available upgrades, and separates them into two categories: available upgrades and excluded upgrades based on predefined exclusion criteria.

### Features

- **Administrator Privileges Check:** Verifies if the script is running with administrator rights. If not, it prompts the user to confirm continuation.
- **Exclusion List:** Defines a list of package names (`$excludePackages`) that are excluded from the upgrade process.
- **Package Parsing:** Parses the output of `winget upgrade` command to extract package details such as Name, Id, Current Version, and Available Version.
- **Output Display:** Displays a clear list of available upgrades and excluded upgrades.
- **User Interaction:** Prompts the user to confirm if they want to proceed with upgrading the available packages.
- **Upgrade Execution:** Executes the upgrade commands for available packages either in regular mode or elevated mode based on user input.

### Usage

1. **Run as Administrator:** It's recommended to run this script with administrator privileges for full functionality.
2. **Exclusion List:** Modify the `$excludePackages` array to exclude specific packages from the upgrade process.
3. **Confirmation:** Respond to prompts (`y/n`) to proceed with upgrades or cancel the operation.
4. **Output:** View detailed information about available and excluded packages before making a decision to upgrade.

### Notes

- Ensure PowerShell execution policy allows running scripts (`Set-ExecutionPolicy`).
- Review and update the `$excludePackages` array to match packages you want to exclude from upgrades.
- For safety, always review the list of upgrades and confirm before proceeding with the upgrade process.

---
