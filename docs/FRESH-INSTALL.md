# Fresh Windows Install Procedure

Goal: go from a freshly-imaged Windows 11 box to the current setup, with `winget` and the PowerShell profile deployed and the captured env restored.

Total time: ~45 min on a fast link, mostly waiting on downloads.

> The PowerShell step is **deliberately manual**, not `winget install`. See [Why manual PowerShell?](#why-manual-powershell) below.

---

## 1. Windows OOBE + winget working

- Complete OOBE, sign in with the MS account that owns your OneDrive (this repo syncs there).
- **Settings -> Windows Update** -> install all updates -> restart.
- **Settings -> Apps -> Installed apps** -> confirm **App Installer** is present. This package is what provides `winget`. If missing, install it from the Microsoft Store.
- Open Terminal -> `winget --version` -> should print a version.
- `winget source update` to refresh sources.

If `winget` is not recognized even though App Installer is installed, repair it from an elevated PowerShell:

```powershell
Add-AppxPackage -Path "https://aka.ms/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
```

---

## 2. PowerShell 7 - manual install

Download and run the MSI from the GitHub release page:

- **https://github.com/PowerShell/PowerShell/releases/latest**
- Pick **`PowerShell-<ver>-win-x64.msi`** (or `x86.msi` if you actually need 32-bit).
- Run elevated. Defaults are fine - installs to `C:\Program Files\PowerShell\7\pwsh.exe` and adds it to `PATH` for all users.
- It installs **side-by-side** with Windows PowerShell 5.1, so nothing breaks.
- Verify: `pwsh --version` from `cmd` or a fresh Terminal tab.

### Why manual PowerShell?

- The MSI is the canonical install; it's signed by Microsoft and ships the day a release is cut.
- `winget` lags GitHub by hours-to-days and you have less control over the install path and feature set.
- Manual install avoids a chicken-and-egg if `winget` itself is misbehaving on first boot.
- You'll have PowerShell 7 to run the profile installer in step 6 even if `winget` is still being repaired.

---

## 3. Essentials via winget

From an elevated PowerShell, either run the script:

```powershell
git clone https://github.com/<you>/general-scripts.git Z:\Personal\general-scripts
Z:\Personal\general-scripts\powershell\tools\Install-Essentials.ps1 -Essentials
```

...or paste the commands individually:

```powershell
winget install --id Microsoft.PowerToys        --accept-source-agreements --accept-package-agreements
winget install --id Microsoft.WindowsTerminal
winget install --id Git.Git                     --source winget
winget install --id 7zip.7zip
winget install --id Microsoft.VisualStudioCode
winget install --id Notepad++.Notepad++
```

These are the OS-level essentials on a Windows dev box - adjust to taste.

---

## 4. Utilities via winget

The ones marked with a star are already wired up by the repo's `User-Profile.ps1`:

```powershell
Z:\Personal\general-scripts\powershell\tools\Install-Essentials.ps1 -Utilities
```

Or individually:

```powershell
winget install --id ajeetdsouza.zoxide       # better cd
winget install --id junegunn.fzf             # fuzzy finder
winget install --id starship.starship        # cross-shell prompt
winget install --id sharkdp.bat                            # better cat
winget install --id eza-community.eza                       # better ls
winget install --id BurntSushi.ripgrep.MSVC                 # better grep
winget install --id sharkdp.fd                             # better find
winget install --id JesseDuffield.lazygit                  # git TUI
winget install --id dan-t.delta                            # git diff viewer
winget install --id jqlang.jq                              # JSON processor
winget install --id MikeFarah.yq                           # YAML processor
```

**Close and reopen Terminal** after this step so the new shims are on `PATH`.

---

## 5. WSL (optional)

Only needed if you use the `zsh/` half of this repo.

```powershell
wsl --install -d Ubuntu
```

Then follow `zsh/README.md`.

---

## 6. Clone the repo + deploy the PowerShell profile

```powershell
git clone https://github.com/<you>/general-scripts.git Z:\Personal\general-scripts
Z:\Personal\general-scripts\powershell\profile\Install-Profile.ps1
```

`Install-Profile.ps1` will:

1. Copy `powershell/profile/User-Profile.ps1` to `$HOME\.config\powershell\user_profile.ps1`.
2. Copy every `*.ps1` in `powershell/functions/` to `$HOME\.config\powershell\functions\`.
3. Write a generated loader into `$PROFILE` that dot-sources the installed files.
4. Run `Set-StarshipConfig.ps1` to pick a `starship.toml` from `starship/`.

Restart PowerShell.

---

## 7. Restore env vars from the captured snapshot

```powershell
# Preview first
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1 -DryRun

# Then apply
Z:\Personal\general-scripts\powershell\tools\Import-Env.ps1
```

The snapshot in `config/env/user.json` excludes secrets, session vars, and runtime vars (see `config/env/README.md` for the filter list).

---

## 8. Toolchain paths

Your custom layout (`Z:\Packages\*`, `F:\Software\...`) is described in `config/env/paths.json`. On a fresh box:

- Re-create the dirs.
- Either reinstall each toolchain into the custom path or symlink the new default location (`%LOCALAPPDATA%`, `%PROGRAMFILES%`, etc.) to your preferred location.
- Update any tool's config to point at the new locations (e.g. `cargo` home, `npm` prefix, `go` GOPATH).

---

## Quick reference

| Step | What | How |
|------|------|-----|
| 1 | winget working | App Installer from MS Store |
| 2 | PowerShell 7 | MSI from github.com/PowerShell/PowerShell/releases |
| 3 | Essentials | `Install-Essentials.ps1 -Essentials` |
| 4 | Utilities | `Install-Essentials.ps1 -Utilities` |
| 5 | WSL | `wsl --install -d Ubuntu` |
| 6 | Profile | `Install-Profile.ps1` |
| 7 | Env restore | `Import-Env.ps1` |
