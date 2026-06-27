# Fresh Windows Install Procedure

Goal: go from a freshly-imaged Windows 11 box to the current setup, with `winget` and the PowerShell profile deployed and the captured env restored.

Total time: ~45 min on a fast link, mostly waiting on downloads.

> The PowerShell step is **deliberately manual**, not `winget install`. See [Why manual PowerShell?](#why-manual-powershell) below.

---

## Pre-flight

### 1. Windows OOBE + winget working

- Complete OOBE, sign in with the MS account that owns your OneDrive (this repo syncs there).
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

The scripts use `$PSScriptRoot`-relative paths so the repo can live anywhere, but `Set-DevPackagePaths.ps1` assumes `Z:\Packages` exists - mount that drive first or edit the `$BasePath` in the script.

### 4. Set up OneDrive and move special folders

Sign in to OneDrive during the initial OOBE flow (it auto-launches). During setup, **change the OneDrive folder location to `E:\OneDrive`** rather than the default `C:\Users\<user>\OneDrive`. Wait for initial sync to finish (or pause sync for now).

Then redirect the standard Windows user folders so Desktop, Documents, Favorites, Music, Pictures, and Videos live on E:\ - with Desktop and Documents inside the OneDrive folder so they sync.

```powershell
Z:\Personal\general-scripts\powershell\profile\Move-Special-Folders.ps1
```

The script uses `robocopy /MOVE` to migrate existing contents, calls `SHSetKnownFolderPath` to update the per-user Known Folder path, edits both `User Shell Folders` and `Shell Folders` registry keys, then restarts Explorer.

**Before running:** close all apps that have Desktop/Documents open (OneDrive, Outlook, etc.). Requires the `E:\` drive to exist and target parent folders (e.g. `E:\OneDrive`) to be present.

### 5. Restore env vars from the captured snapshot

Run **before** the winget installs, so toolchain path env vars (CARGO_HOME, GOPATH, etc.) are in place when those toolchains first launch. The `OneDrive` env var in the snapshot points at `E:\OneDrive`, which is why step 4 (moving Desktop/Documents there) must come first.

```powershell
# Preview first
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1 -DryRun

# Then apply
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1
```

The snapshot in `config/env/user.json` excludes secrets, session vars, and runtime vars (see `config/env/README.md` for the filter list).

### 6. Set dev package paths

`Set-DevPackagePaths.ps1` redirects common toolchain caches (NuGet, Go, Cargo, npm, PyPI, Ruby, Maven) into `Z:\Packages\...`. Run **before** `winget install` for the same reason as step 5.

```powershell
Z:\Personal\general-scripts\powershell\profile\Set-DevPackagePaths.ps1
```

Pick User (no admin) or System scope (admin required). Creates the target directories and writes the registry env vars. **Restart your terminal or reboot** when done so subsequent processes inherit the new vars.

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

**Close and reopen Terminal** after this step so the new shims are on `PATH`.

---

## Post-install scripts

### 8. Run these in order

These are the repo scripts that need to run once on a fresh box, in this order. Most require an elevated PowerShell (admin).

1. **`Install-Profile.ps1`** - copies `User-Profile.ps1` and `functions/` to `~/.config/powershell/`, writes a generated loader into `$PROFILE`, runs `Set-StarshipConfig.ps1` to pick a `starship.toml`. *No admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\profile\Install-Profile.ps1
   ```

2. **`Update-GitCommitIdentity.ps1`** - sets `git config user.name` and `user.email` so your commits are attributed correctly. *No admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\tools\Update-GitCommitIdentity.ps1
   ```

3. **`Invoke-RegistryTweaks.ps1`** - applies the registry tweaks in `registry-tweaks/dos/*.reg`. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Invoke-RegistryTweaks.ps1
   ```

4. **`Set-NetworkAdapter.ps1`** - network adapter tweaks (offloads, RSS, etc.). *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Set-NetworkAdapter.ps1
   ```

5. **`Optimize-Shutdown.ps1`** - speeds up Windows shutdown by reducing the wait-for-kill timeout. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Optimize-Shutdown.ps1
   ```

6. **`Set-DlssIndicator.ps1`** *(optional, gaming)* - toggles the DLSS frame-generation indicator on/off. *Admin required.*
   ```powershell
   Z:\Personal\general-scripts\powershell\system\Set-DlssIndicator.ps1
   ```

### 9. Restart PowerShell

After all of the above, close every PowerShell window and reopen. The new `$PROFILE` loader, env vars, and winget shims all need a fresh session.

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
| 1 | winget working | App Installer from MS Store |
| 2 | PowerShell 7 | MSI from github.com/PowerShell/PowerShell/releases |
| 3 | Clone repo | `git clone ...` |
| 4 | OneDrive + special folders | `Move-Special-Folders.ps1` |
| 5 | Restore env vars | `Import-Env.ps1` (before winget) |
| 6 | Dev package paths | `Set-DevPackagePaths.ps1` (admin for System scope) |
| 7 | Apps via winget | `Install-Essentials.ps1` |
| 8 | Post-install scripts | Run the 6 numbered scripts in order |
| 9 | Restart PowerShell | close + reopen |
| 10 | WSL (optional) | `wsl --install -d Ubuntu` |
