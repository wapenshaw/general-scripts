# Personal workstation toolbox

macOS and Linux use **zsh**. Windows uses **PowerShell 7 + Windows Terminal**. First-run installers are failsafe: a missing package manager or package does not abort the rest. The Windows bootstrap downloads the official App Installer bundle when `winget` is missing; the Mac bootstrap treats missing `uv` as expected until its tool-install phase. See [CHANGELOG.md](./CHANGELOG.md) for what changed and why.

| OS | First-run | Later updates | Shell config |
|----|-----------|---------------|--------------|
| **macOS** | [`macos/install.zsh`](./macos/install.zsh) — installs Homebrew if needed, then CLI tools + rustup, then zsh | [`mac-update.zsh`](./mac-update.zsh) | [`zsh/install.sh --base`](./zsh/install.sh) |
| **Fedora / Ubuntu / WSL** | [`linux/install.sh`](./linux/install.sh) — `dnf` or `apt-get`, official fallbacks, then zsh | re-run `linux/install.sh --update` | [`zsh/install.sh`](./zsh/install.sh) (personal by default) |
| **Windows 11** | [`powershell/tools/Install-Workstation.ps1`](./powershell/tools/Install-Workstation.ps1) — App Installer/winget + profile | [`Update-WinGetPackages.ps1`](./powershell/tools/Update-WinGetPackages.ps1) | [`Install-Profile.ps1`](./powershell/profile/Install-Profile.ps1) |

```bash
# macOS
./macos/install.zsh                 # personal (default)
./macos/install.zsh --assurant      # Assurant/Astra modules
./mac-update.zsh                    # later Homebrew / mise / rustup / uv updates
./mac-update.zsh --bootstrap        # install Homebrew if missing + curated tools

# Fedora, Ubuntu, Debian, WSL
./linux/install.sh                  # personal (default)
./linux/install.sh --assurant       # Assurant/Astra modules
./linux/install.sh --base           # explicit personal profile
./linux/install.sh --update         # also upgrade installed packages
```

```powershell
# Windows — elevated pwsh recommended; repairs winget if needed
pwsh -File .\powershell\tools\Install-Workstation.ps1
pwsh -File .\powershell\tools\Install-Workstation.ps1 -Assurant
```

On a brand-new Windows box, follow **[docs/FRESH-INSTALL.md](./docs/FRESH-INSTALL.md)** (steps 1–6) for drive layout, the desired storage manifest and nvm/uv runtime setup before the workstation installer. Windows uses nvm v2 for Node, standalone pnpm and uv for Python, with development storage under `Z:\Packages`.

Cargo/rustup PATH is added only when the `cargo` binary exists (zsh: `~/.cargo/bin/cargo`; PowerShell: `$env:CARGO_HOME\bin\cargo.exe` or `~\.cargo\bin\cargo.exe`). `rustup self uninstall` therefore drops it off PATH.

---

> AI agents: See the project guide at [.github/copilot-instructions.md](.github/copilot-instructions.md) for repo structure, workflows, and conventions.

## 1. [PowerShell Profile Installer](./powershell/profile/Install-Profile.ps1)

Deploys the modular PowerShell profile (modules + functions + starship theme). For a brand-new Windows box, follow the ordered playbook in **[docs/FRESH-INSTALL.md](./docs/FRESH-INSTALL.md)** — do not start with this script alone.

### Prerequisites (before `Install-Profile.ps1`)

Install these **before** running the profile installer. The profile will still load if optional CLIs are missing (each init is try/catch-guarded), but the prompt and tools will be incomplete.

| Need | How | Required? |
|------|-----|-----------|
| **winget** | Windows **App Installer** (Microsoft Store). Verify: `winget --version`; the workstation bootstrap repairs it if missing | Required for direct `Install-Essentials.ps1`; repaired automatically by the workstation bootstrap |
| **PowerShell 7 (`pwsh`)** | **Manual MSI** from [PowerShell releases](https://github.com/PowerShell/PowerShell/releases/latest) — not via winget. Verify: `pwsh --version` | Yes |
| **Git** | `winget` / [Install-Essentials.ps1](./powershell/tools/Install-Essentials.ps1) | Yes (clone + git helpers) |
| **starship, zoxide, fzf** | `Install-Essentials.ps1` (Utilities list) | Strongly recommended — prompt, `cd` jumper, fuzzy find |
| **eza, bat, ripgrep, nvm, …** | Same essentials script | Optional; aliases/modules no-op if absent |
| **Windows Terminal** | Essentials list | Recommended host for `pwsh` |

Minimal CLI path:

```powershell
# Elevated pwsh recommended — packages + profile
.\powershell\tools\Install-Workstation.ps1
# Close and reopen the terminal so starship/zoxide/fzf/cargo are on PATH
```

If `winget` is missing, `Install-Workstation.ps1` downloads the official
Microsoft App Installer bundle to a temporary file, installs it, and retries
the package pass. If the new `winget` shim is not visible immediately, open a
new PowerShell window and re-run the installer.

Utilities-only (shell tools without PowerToys/VS Code/etc.):

```powershell
.\powershell\tools\Install-Essentials.ps1 -Utilities
```

See `Install-Essentials.ps1 -List` for package IDs. Full fresh-box order (OOBE → storage manifest → runtimes and tools → profile) is in [docs/FRESH-INSTALL.md](./docs/FRESH-INSTALL.md).

### What the installer does

1. Copies `powershell/profile/modules/*.ps1` → `~/.config/powershell/modules/`
2. Copies `powershell/functions/*.ps1` → `~/.config/powershell/functions/`
3. Installs `Register-ProfileFunctions.ps1` (lazy-loads functions; registers short aliases like `rsb` immediately)
4. Installs the loader and explicit module manifest under `~/.config/powershell/`, with a thin AllHosts entry point
5. Removes separate ConsoleHost/VS Code profile files after backing them up; both hosts use AllHosts
6. Keeps the existing Starship theme; installs `nova` only if missing, or replaces it with an explicit `-StarshipTheme`

Re-running backs up the live configuration and deploys selected dependencies to a local module store. Does **not** install winget, PowerShell, starship, fonts, or runtimes. See [the shell setup guide](./powershell/profile/README.md).

### Usage

```powershell
pwsh -File .\powershell\profile\Install-Profile.ps1

# Common flags
pwsh -File .\powershell\profile\Install-Profile.ps1 -Assurant          # Assurant modules + $env:PS_ASSURANT=1
pwsh -File .\powershell\profile\Install-Profile.ps1 -StarshipTheme nordic
pwsh -File .\powershell\profile\Install-Profile.ps1 -Uninstall
```

Restart PowerShell after running. PSFzf is deployed by the installer; startup never downloads dependencies. Node uses nvm v2, Python uses uv, and pnpm is standalone without Corepack.

Windows Terminal and VS Code share the same PowerShell 7 configuration. After
environment changes, fully quit VS Code and reopen it from Start before creating
a terminal. See [VS Code troubleshooting](./powershell/profile/README.md#vs-code-and-terminal-differences)
and the [September 2026 cleanup record](./docs/POWERSHELL-SETUP-REVIEW.md).

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

## 3. [Zsh configuration](./zsh/) (macOS, Linux, WSL)

Modular zsh config (`~/.zsh`). `zsh/install.sh` copies the payload; it does **not** install packages. Use `./macos/install.zsh` or `./linux/install.sh` for first-run tool bootstrap.

See [zsh/README.md](./zsh/README.md) and [zsh/CHEATSHEET.md](./zsh/CHEATSHEET.md).

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
