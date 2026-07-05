# Fresh Windows Install Procedure

Goal: go from a freshly-imaged Windows 11 box to the current setup, with `winget` and the PowerShell profile deployed and the captured env restored.

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

The scripts use `$PSScriptRoot`-relative paths so the repo can live anywhere. `Set-DevPackagePaths.ps1` (step 6) requires the `Z:` drive to be mounted — it creates `Z:\Packages` and all its subfolders itself, so only the drive needs to exist. To use a different drive, edit the `$BasePath` in the script.

### 4. Set up OneDrive and move special folders

Verify OneDrive is signed in (it should have been set up in step 1 during OOBE). If not, sign in now. **Confirm the OneDrive folder location is `E:\OneDrive`** rather than the default `C:\Users\<user>\OneDrive` — change it under OneDrive → Settings → Account → Choose folders.

Then redirect the standard Windows user folders so Desktop, Documents, Favorites, Music, Pictures, and Videos live on E:\ - with Desktop and Documents inside the OneDrive folder so they sync.

```powershell
Z:\Personal\general-scripts\powershell\profile\Move-Special-Folders.ps1
```

The script uses `robocopy /MOVE` to migrate existing contents, calls `SHSetKnownFolderPath` to update the per-user Known Folder path, edits both `User Shell Folders` and `Shell Folders` registry keys, then restarts Explorer. *No admin required.*

**Before running:** close all apps that have Desktop/Documents open (OneDrive, Outlook, etc.). **Pause OneDrive sync** before running the script to avoid sync conflicts while robocopy is moving files into `E:\OneDrive\Documents` — resume sync after the script finishes. Requires the `E:\` drive to exist and target parent folders (e.g. `E:\OneDrive`) to be present.

### 5. Restore env vars from the captured snapshot

Run **before** the winget installs, so toolchain path env vars (CARGO_HOME, GOPATH, etc.) are in place when those toolchains first launch. The `OneDrive` env var in the snapshot points at `E:\OneDrive`, which is why step 4 (moving Desktop/Documents there) must come first.

```powershell
# Preview first
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1 -DryRun

# Then apply — use -MergePath to preserve the live PATH (recommended on a fresh box
# where winget/App Installer have already injected shims into PATH)
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1 -MergePath
```

The snapshot in `config/env/user.json` excludes secrets, session vars, and runtime vars (see `config/env/README.md` for the filter list). *No admin needed for the default `user.json` apply. Re-run with `-IncludeMachine` in an elevated shell to also restore the system-scope env vars from `system.json`.*

> **`-MergePath` vs default:** without `-MergePath`, the captured `Path` from `user.json` **replaces** the live `PATH` entirely. On a fresh box this can clobber shims that App Installer / winget just added (e.g. `%LOCALAPPDATA%\Microsoft\WindowsApps`). Use `-MergePath` to merge the captured entries into the live `PATH` instead of replacing it. Run `Import-Env.ps1 -DryRun` first to preview the diff.

> **Why before winget:** the env vars point toolchain caches at `Z:\Packages\*`. The toolchains installed in step 7 (Rustup, mise, Go, etc.) read these vars on first launch. If you skip ahead and run them before step 5/6, they'll write their first packages to `C:\Users\...` and you'll have to relocate them manually.

### 6. Set dev package paths

`Set-DevPackagePaths.ps1` redirects common toolchain caches (NuGet, Go, Cargo, npm, PyPI, Ruby, Maven) into `Z:\Packages\...`. Run **before** `winget install` for the same reason as step 5.

```powershell
Z:\Personal\general-scripts\powershell\profile\Set-DevPackagePaths.ps1
```

Pick User (no admin) or System scope (admin required). Creates the target directories and writes the registry env vars. **Restart your terminal or reboot** when done so subsequent processes inherit the new vars.

> **Why before winget:** same as step 5 — toolchains read these cache paths on first launch.

---

## Install

### 7. Apps via winget

From an elevated PowerShell:

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

### 8. Run these in order

These are the repo scripts that need to run once on a fresh box, in this order. Most require an elevated PowerShell (admin).

1. **`Install-Profile.ps1`** - deploys the modular PowerShell profile: copies `modules/*.ps1` and `functions/*.ps1` to `~/.config/powershell/`, writes a generated loader into `$PROFILE` that sources modules in dependency order (history → exports → completion → fzf → tools → aliases → functions → bindings → plugins → uv → vsdev → prompt), runs `Set-StarshipConfig.ps1` to install the `nova` starship theme. *No admin required.* **Must run after step 7** — the profile modules invoke `starship init`, `zoxide init`, and `Microsoft.WinGet.CommandNotFound` on every shell start, all of which require binaries/modules installed in step 7 (and step 1). Every init is guarded by `try/catch` so a missing tool prints a warning but never breaks the shell. The `11-vsdev` module silently activates the Visual Studio Developer Shell (MSVC + Windows SDK on PATH/INCLUDE/LIB) when VS is installed and no-ops otherwise.
   ```powershell
   Z:\Personal\general-scripts\powershell\profile\Install-Profile.ps1
   ```
   **Flags:**
   - `-Work` — also installs `modules/work/` and sets `$env:PS_WORK = '1'` in the loader so work-only aliases, exports, and functions are sourced on every shell start. Mirrors `zsh/install.sh --work`.
   - `-StarshipTheme <name>` — override the starship theme (defaults to `nova`; e.g. `-StarshipTheme nordic`). Also settable via `$env:PS_STARSHIP_THEME`.
   - `-Uninstall` — back up `~/.config/powershell/` to `~/.config/powershell.uninstalled.<timestamp>`, restore `$PROFILE` from pre-install backup. Mutually exclusive with all other flags.
   - `-ExcludeModules <names>` — skip specific module files (e.g. `-ExcludeModules '10-uv.ps1'`).
   - `-InstallDir <path>` — override the install destination (default: `$HOME\.config\powershell`).

   **Auto-plugins:** the `09-plugins.ps1` module auto-installs `Terminal-Icons`, `posh-git`, and `PSFzf` from PSGallery on first shell launch (analogous to zsh's `plugins.zsh`). Override with `$env:PS_PLUGINS = 'Terminal-Icons,PSFzf'` or disable with `$env:PS_PLUGINS = ''`.

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
| 5 | Restore env vars | `Import-Env.ps1` (before winget; `-IncludeMachine` needs admin) |
| 6 | Dev package paths | `Set-DevPackagePaths.ps1` (admin for System scope) |
| 7 | Apps via winget | `Install-Essentials.ps1` (installs starship + zoxide) |
| 8 | Post-install scripts | Run the numbered scripts in order |
| 9 | Restart PowerShell + reboot | close + reopen, then one full Windows reboot |
| 10 | WSL (optional) | `wsl --install -d Ubuntu` |