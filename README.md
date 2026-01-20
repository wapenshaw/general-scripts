# General Scripts I use on a Windows 11 install

### Should also work for Windows 10 and other similar Editions of Windows

---

> AI agents: See the project guide at [.github/copilot-instructions.md](.github/copilot-instructions.md) for repo structure, workflows, and conventions.

## 1. [PowerShell Script to Install Starship, Update Profile, and Install Fonts](./scripts/install-profile.ps1)

This PowerShell script automates the following tasks:

1. **Check for Winget Installation**: The script checks if Winget is installed on the system. If Winget is not installed, it prompts the user to install it.
2. **Install Starship Prompt**: Using Winget, the script installs the Starship prompt.
3. **Update PowerShell Profile**: The script overwrites the current PowerShell profile with the contents of a specified `myprofile.ps1` file.
4. **Install Fonts**: The script installs all fonts located in the `fonts/nerd-fonts` and `fonts/coding-fonts` directories, ensuring that already installed fonts are skipped.

### Usage

1. Ensure that the `myprofile.ps1` file is present in the same directory as the script.
2. Place your font files in the `fonts/nerd-fonts` and `fonts/coding-fonts` directories.
3. Run the script in a PowerShell session.

This script simplifies setting up a development environment by automating the installation of essential tools and configurations.

---

## 2. [Windows Package Upgrader Script](./scripts/winget-upgrade-all-except.ps1)

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

## 3. [Copy Starship Configuration Script](./scripts/starship.ps1)

### Description

This PowerShell script allows you to select a file from the `starship/` directory and copy it to `$HOME/.config/starship.toml`. It lists all files in the `starship/` folder, presents them in a numbered menu, and prompts you to choose which file to copy. After selecting a file, it creates the destination directory if it doesn't exist and copies the chosen file to `$HOME/.config/starship.toml`. This script ensures you copy the correct file interactively, enhancing file management efficiency.
