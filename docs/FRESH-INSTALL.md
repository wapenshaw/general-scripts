# Fresh Windows Install Procedure

Goal: go from a freshly-imaged Windows 11 box to the current setup, with development storage configured from the manifest, runtimes installed, and the shared PowerShell profile deployed.

Total time: ~45 min on a fast link, mostly waiting on downloads.

> The PowerShell step is **deliberately manual**, not `winget install`. See [Why manual PowerShell?](#why-manual-powershell) below.

---

## Pre-flight

### 1. Windows OOBE + winget working

- Complete OOBE, sign in with the MS account that owns your OneDrive (this repo syncs there). OneDrive setup also happens during OOBE — **change the OneDrive folder location to `E:\OneDrive`** rather than the default `C:\Users\<user>\OneDrive` when prompted. Wait for initial sync to finish (or pause sync for now).
- **Settings -> Windows Update** -> install all updates -> restart.
- **Settings -> Apps -> Installed apps** -> confirm **App Installer** is present. This package is what provides `winget`. If missing, install it from the Microsoft Store.
- Open Terminal -> `winget --version` -> should print a version.
- `winget source update` to refresh sources.

If `winget` is not recognized even though App Installer is installed, repair it from an elevated PowerShell:

```powershell
Add-AppxPackage -Path "https://aka.ms/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
```

### 2. PowerShell 7 - manual install

Download and run the MSI from the GitHub release page:

- **https://github.com/PowerShell/PowerShell/releases/latest**
- Pick **`PowerShell-<ver>-win-x64.msi`** (or `x86.msi` if you actually need 32-bit).
- Run elevated. Defaults are fine - installs to `C:\Program Files\PowerShell\7\pwsh.exe` and adds it to `PATH` for all users.
- It installs **side-by-side** with Windows PowerShell 5.1, so nothing breaks.
- Verify: `pwsh --version` from `cmd` or a fresh Terminal tab.

#### Why manual PowerShell?

- The MSI is the canonical install; it's signed by Microsoft and ships the day a release is cut.
- `winget` lags GitHub by hours-to-days and you have less control over the install path and feature set.
- Manual install avoids a chicken-and-egg if `winget` itself is misbehaving on first boot.
- You'll have PowerShell 7 to run the profile installer in step 8 even if `winget` is still being repaired.

---

## Setup

### 3. Clone the repo

```powershell
git clone https://github.com/<you>/general-scripts.git Z:\Personal\general-scripts
```

The scripts use `$PSScriptRoot`-relative paths so the repo can live anywhere. `Set-DevPackagePaths.ps1` (step 5) requires the configured drive to be mounted and creates the storage folders. For a different drive during initial setup, edit `root` in `config/env/development.json` or pass `-Root`; this does not migrate existing runtime installations.

### 4. Set up OneDrive and move special folders

Verify OneDrive is signed in (it should have been set up in step 1 during OOBE). If not, sign in now. **Confirm the OneDrive folder location is `E:\OneDrive`** rather than the default `C:\Users\<user>\OneDrive` — change it under OneDrive → Settings → Account → Choose folders.

Then redirect the standard Windows user folders so Desktop, Documents, Favorites, Music, Pictures, and Videos live on E:\ - with Desktop and Documents inside the OneDrive folder so they sync.

```powershell
Z:\Personal\general-scripts\powershell\profile\Move-Special-Folders.ps1
```

The script uses `robocopy /MOVE` to migrate existing contents, calls `SHSetKnownFolderPath` to update the per-user Known Folder path, edits both `User Shell Folders` and `Shell Folders` registry keys, then restarts Explorer. *No admin required.*

**Before running:** close all apps that have Desktop/Documents open (OneDrive, Outlook, etc.). **Pause OneDrive sync** before running the script to avoid sync conflicts while robocopy is moving files into `E:\OneDrive\Documents` — resume sync after the script finishes. Requires the `E:\` drive to exist and target parent folders (e.g. `E:\OneDrive`) to be present.

### 5. Configure the Dev Drive storage manifest

`config/env/development.json` defines the desired User environment and package
storage. Review its root (`Z:\Packages`) before applying it. Historical environment
snapshots are recovery data; do not restore their PATH on a fresh machine.

```powershell
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1 -WhatIf
pwsh -NoProfile -File ./powershell/profile/Set-DevPackagePaths.ps1
```

This creates storage directories and backs up changes outside the repo. It writes
pnpm storage settings to global `config.yaml`, keeps npm/pip cache configuration in
User environment variables, and preserves credentials/unrelated tool settings.

### 6. Runtime ownership

Use nvm v2 for Node, uv for Python, and standalone pnpm without Corepack. Runtime
versions and nvm storage paths are pinned in the development manifest. Install the
runtime tools after the winget utilities in step 7:

```powershell
pwsh -NoProfile -File ./powershell/profile/Install-NodeToolchain.ps1
# Install uv if it is missing, then:
uv python install 3.14 --default
uv tool install --python 3.14 poetry
uv tool install --python 3.14 deptry
```

Node/nvm data, Python installations and environments, Rust toolchains and package
caches use Z:. Vendor-managed IDEs, .NET, Java, Go and CUDA retain their supported
installation locations. Restart applications after environment changes.
See [the shell setup guide](../powershell/profile/README.md).

---

## Install

### 7. Apps via winget

From an elevated PowerShell 7 session, either run the one-shot workstation installer (packages **and** the profile from step 8.1):

```powershell
Z:\Personal\general-scripts\powershell\tools\Install-Workstation.ps1
# optional: -Assurant    -SkipPackages    -SkipProfile    -StarshipTheme nordic
```

or install packages only:

```powershell
Z:\Personal\general-scripts\powershell\tools\Install-Essentials.ps1
```

Defaults to installing both `-Essentials` (PowerToys, Windows Terminal, Git, 7-Zip, VS Code, Notepad++) and `-Utilities` (zoxide, fzf, starship, plus other dev/CLI tools - see `$UtilitiesList` in the script for the full current list).

The script:

- refreshes `winget` sources,
- installs each package with `--accept-source-agreements --accept-package-agreements`,
- tracks per-package failures and reports them at the end rather than aborting on the first one,
- is idempotent - `winget` skips packages that are already installed at the requested version.

For a list of what would be installed: `Install-Essentials.ps1 -List`.

**Close and reopen Terminal** after this step so the new shims (`starship`, `zoxide`, `fzf`, etc.) are on `PATH`. Step 8.1 below depends on `starship` and `zoxide` being available — if any of these failed to install, fix them before continuing.

---

## Post-install scripts

After Node and uv are installed, optionally deploy the portable AI client settings
using [ai/README.md](../ai/README.md). Its shared MCP registry generates native
definitions for Claude Code, Codex, Grok and OpenCode. Install the CLI binaries and
authenticate separately; existing account state is not imported into the repo.

### 8. Run these in order

These are the repo scripts that need to run once on a fresh box, in this order. Most require an elevated PowerShell (admin).

1. **`Install-Profile.ps1`** deploys a local PowerShell 7 profile and dependencies.
   Skip this step if `Install-Workstation.ps1` already deployed it in step 7.
   It backs up the live setup, installs configuration under `~/.config/powershell`,
   deploys plugins to `~/.local/share/powershell/Modules`, and writes a thin AllHosts
   entry point. `installed-profile.json` selects modules explicitly; excluded or
   stale files never load. Work configuration loads before the prompt.
   ```powershell
   pwsh -NoProfile -File ./powershell/profile/Install-Profile.ps1
   ```
   **Flags:** `-Work` (alias `-Assurant`) enables work settings while preserving private installed
   files; `-Plugins PSFzf,posh-git` adds Git completion; `-SkipPlugins` skips
   dependency deployment; `-StarshipTheme <name>` explicitly replaces the theme;
   `-ExcludeModules <names>` changes the load manifest; `-InstallDir` and
   `-ModuleDir` override local locations; `-Uninstall` restores the original setup.

   Startup imports PSFzf without installing packages or changing gallery trust.
   Existing Starship configuration is retained. Script/command invocations skip
   interactive setup; opt in with `PS_PROFILE_IN_SCRIPTS=1`. Use `vsdev` when MSVC
   and Windows SDK variables are needed. Ordinary terminals have no automatic
   developer-shell activation, mise activation, or conda initialization.

   Windows Terminal, VS Code terminals and the PowerShell extension console share
   the AllHosts profile. Separate ConsoleHost/VS Code profile files are backed up
   and removed. Interactive VS Code `-NoExit -Command` launches load the profile.
   After installation/environment changes, fully quit VS Code and reopen it from
   Start, then open a fresh terminal. See [shell troubleshooting](../powershell/profile/README.md#vs-code-and-terminal-differences).

2. **Set git identity** for future commits on this box. *No admin required.*
   ```powershell
   git config --global user.name  'Your Name'
   git config --global user.email 'you@example.com'
   ```
   > `powershell\tools\Update-GitCommitIdentity.ps1` is **not** part of the fresh-install flow — it rewrites existing commit history via `git filter-branch` and is for fixing attribution across an existing repo, not configuring a new system.

3. **`Invoke-RegistryTweaks.ps1`** - applies the registry tweaks in `registry-tweaks/dos/*.reg`. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Invoke-RegistryTweaks.ps1
   ```

4. **`Set-NetworkAdapter.ps1`** - configures a named adapter with static IPv4, DNS-over-HTTPS (Cloudflare + Google), and NetBIOS over TCP/IP. **Edit the hard-coded `$interfaceAlias`, `$ipv4Address`, `$gateway`, and `$dnsServers` at the top of the script before running** — the defaults target a specific home network. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Set-NetworkAdapter.ps1
   ```

5. **`Optimize-Shutdown.ps1`** - speeds up Windows shutdown by reducing the wait-for-kill timeout. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Optimize-Shutdown.ps1
   ```

6. **`Set-DlssIndicator.ps1`** *(optional, gaming)* - toggles the DLSS frame-generation indicator on/off. Requires NVIDIA App / NGX to be installed (the script silently no-ops with "Registry path not found" if the `HKLM:\SOFTWARE\NVIDIA Corporation\Global\NGXCore` key is missing). *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Set-DlssIndicator.ps1
   ```

> **Optional system tweaks not listed above** (run as needed):
> - `powershell\system\Disable-WebSearch.ps1` — disables web results in Windows Search via three `HKLM\...\Windows Search` policy DWORDs. There is no equivalent `.reg` file under `registry-tweaks/dos\`, so this is the only way to apply it. *Admin required.*
> - `powershell\system\fontcache.bat` — rebuilds the Windows font cache. Run from an elevated `cmd.exe` after installing any custom terminal font. *Admin required.*
> - `powershell\functions\Install-Font.ps1` / `Set-KeyboardLayout.ps1` — these are profile functions, not standalone scripts. After step 8.1 + 9, run `Install-Fonts -fontFolders <path>` or `skl` from any PowerShell window.

### 9. Restart PowerShell (and reboot once at the end)

After all of the above, close every PowerShell window and reopen. The new `$PROFILE` loader, env vars, and winget shims all need a fresh session.

> **Reboot recommended.** The registry tweaks applied in step 8.3 and the shutdown-timeout changes in step 8.5 take effect only on a full Windows restart, not a PowerShell restart. Do one reboot at the end of the post-install block to make them stick.

---

## Optional

### 10. WSL

Only needed if you use the `zsh/` half of this repo.

```powershell
wsl --install -d Ubuntu
```

Then follow `zsh/README.md`.

---

## Quick reference

| Step | What | How |
|------|------|-----|
| 1 | winget working + OneDrive at `E:\OneDrive` | App Installer from MS Store; OneDrive folder set during OOBE |
| 2 | PowerShell 7 | MSI from github.com/PowerShell/PowerShell/releases |
| 3 | Clone repo | `git clone ...` |
| 4 | Move special folders | `Move-Special-Folders.ps1` (pause OneDrive sync first) |
| 5 | Desired storage settings | `Set-DevPackagePaths.ps1` (User scope) |
| 6 | Runtime ownership | `Install-NodeToolchain.ps1`, then uv Python/tools |
| 7 | Apps via winget | `Install-Essentials.ps1` (installs starship + zoxide) |
| 8 | Post-install scripts | Run the numbered scripts in order |
| 9 | Restart PowerShell + reboot | close + reopen, then one full Windows reboot |
| 10 | WSL (optional) | `wsl --install -d Ubuntu` |
