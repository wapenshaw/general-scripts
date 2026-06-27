# General Scripts I use on a Windows 11 install

### Should also work for Windows 10 and other similar Editions of Windows

---

> AI agents: See the project guide at [.github/copilot-instructions.md](.github/copilot-instructions.md) for repo structure, workflows, and conventions.

## 1. [PowerShell Profile Installer](./powershell/profile/Install-Profile.ps1)

Installs the repo's PowerShell profile and helper functions into the user's XDG config directory, then runs the starship config picker.

1. **Install User Profile**: Copies `powershell/profile/User-Profile.ps1` to `$HOME/.config/powershell/user_profile.ps1`.
2. **Install Functions**: Copies every `*.ps1` in `powershell/functions/` to `$HOME/.config/powershell/functions/`.
3. **Generate Profile Loader**: Writes a generated loader into `$PROFILE` (the live PowerShell profile path) that dot-sources the installed files.
4. **Pick Starship Config**: Runs `Set-StarshipConfig.ps1` to interactively choose a `starship.toml` from `starship/` and copy it to `$HOME/.config/starship.toml`.

Re-running is idempotent — existing files are overwritten in place. Does **not** install winget, starship, or fonts; those are prerequisites.

### Usage

```powershell
pwsh -File .\powershell\profile\Install-Profile.ps1
```

Restart PowerShell after running to apply the new profile.

---

## 2. [Windows Package Upgrader Script](./powershell/tools/Update-WinGetPackages.ps1)

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

## 3. [WSL Zsh Configuration](./zsh/)

A modular zsh setup for WSL Ubuntu built around starship, eza, bat, fzf, zoxide, mise, and uv. Config is split into focused files (aliases, bindings, completion, exports, etc.) all living under `~/.zsh/` via ZDOTDIR. Symlink-based install — editing the repo file edits the live config.

```bash
bash ~/wapenshaw/zsh/install.sh
```

See [zsh/README.md](./zsh/README.md) for the full setup guide and [zsh/CHEATSHEET.md](./zsh/CHEATSHEET.md) for all aliases and keybindings.

---

## 4. [Copy Starship Configuration Script](./powershell/profile/Set-StarshipConfig.ps1)

### Description

This PowerShell script allows you to select a file from the `starship/` directory and copy it to `$HOME/.config/starship.toml`. It lists all files in the `starship/` folder, presents them in a numbered menu, and prompts you to choose which file to copy. After selecting a file, it creates the destination directory if it doesn't exist and copies the chosen file to `$HOME/.config/starship.toml`. This script ensures you copy the correct file interactively, enhancing file management efficiency.

---

## 5. [Move Special Folders](./powershell/profile/Move-Special-Folders.ps1)

One-time script for a fresh box. Redirects the standard Windows user folders (Desktop, Documents, Favorites, Music, Pictures, Videos) to `E:\` so the user data lives on a separate drive and Desktop/Documents are inside `E:\OneDrive` for sync.

Uses `robocopy /MOVE` to migrate existing contents, calls `SHSetKnownFolderPath`, edits the `User Shell Folders` and `Shell Folders` registry keys, and restarts Explorer. Prints a summary of which Known Folders now live on `E:\`.

### Usage

```powershell
.\powershell\profile\Move-Special-Folders.ps1
```

**Before running:** close Explorer and any app that has Desktop/Documents open. Requires the `E:\` drive and the `E:\OneDrive` parent folder to exist.

---

## 6. [Font Cache Reset](./powershell/system/fontcache.bat)

Windows batch script that resets the Windows font cache. Useful when fonts fail to render correctly or after bulk-installing new fonts.

**Requires Administrator.** Stops the `FontCache` service, grants the current user access to `%WinDir%\ServiceProfiles\LocalService`, deletes the font cache files (`FontCache*` and `FNTCACHE.DAT`), then restarts the service.

### Usage

Run from an elevated Command Prompt or PowerShell:

```cmd
.\powershell\system\fontcache.bat
```
