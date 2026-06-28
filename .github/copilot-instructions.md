# AI Coding Agent Guide

This repo is a personal toolbox, not an application: Windows-focused PowerShell utilities, shell/profile configuration payloads, Starship/font/terminal assets, browser-extension snippets, and a TP-Link ER605 v2 OpenWrt flashing helper. There is no repo-wide package manager, build system, or test harness; validate the specific script family you touch.

## Commands

PowerShell workflows:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
pwsh -File ./powershell/profile/Install-Profile.ps1
pwsh -File ./powershell/tools/Update-WinGetPackages.ps1 -ExcludePackages Youtube,Filebot
pwsh -File ./powershell/profile/Set-DevPackagePaths.ps1
pwsh -File ./powershell/system/Set-NetworkAdapter.ps1
```

Zsh workflows:

```bash
./zsh/install.sh
./zsh/install.sh --work
./zsh/install.sh --uninstall
```

OpenWrt ER605 workflows run on the router, not from the workstation:

```sh
sh ./er605-openwrt/er605-mtd-backup.sh
sh ./er605-openwrt/er605v2_write_initramfs.sh openwrt-initramfs.bin
```

Script-level validation:

```bash
# All tracked PowerShell scripts
pwsh -NoProfile -Command '$failed=$false; Get-ChildItem ./powershell -Recurse -Filter *.ps1 | ForEach-Object { $tokens=$null; $errors=$null; $null = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors); if ($errors) { $failed=$true; $errors | Format-List } }; if ($failed) { exit 1 }'

# Single PowerShell script
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; $null = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path ./powershell/profile/Set-DevPackagePaths.ps1).Path,[ref]$tokens,[ref]$errors); if ($errors) { $errors | Format-List; exit 1 }'

# POSIX shell entry points
for f in ./er605-openwrt/*.sh; do sh -n "$f"; done

# Bash entry point
bash -n ./zsh/install.sh

# Single shell script
sh -n ./er605-openwrt/er605v2_write_initramfs.sh

# Zsh config modules
zsh -n ./zsh/zsh/.zshenv ./zsh/zsh/.zprofile ./zsh/zsh/.zshrc ./zsh/zsh/*.zsh ./zsh/zsh/work/*.zsh
```

## High-level architecture

- `powershell/` contains runnable, task-oriented PowerShell utilities organised by intent: `profile/` (install + startup), `system/` (registry/network/shutdown tweaks), `tools/` (ad-hoc and daily helpers), `diagnostics/` (Test-* probes). `powershell/functions/` contains reusable helpers and aliases that become available through the PowerShell profile installer.
- `powershell/profile/Install-Profile.ps1` deploys the modular PowerShell profile: copies `powershell/profile/modules/*.ps1` and `powershell/functions/*.ps1` to `$HOME\.config\powershell\`, writes `$PROFILE` as a generated loader that dot-sources modules in dependency order (numeric prefix `NN-name.ps1`, sorted), then runs `powershell/profile/Set-StarshipConfig.ps1`. Supports `-Work` (installs `modules/work/` + sets `$env:PS_WORK`), `-Uninstall` (backup + restore), `-StarshipTheme <name>` (skip interactive picker), `-ExcludeModules`, and `-InstallDir`.
- `powershell/profile/modules/` contains the modular profile files, each owning one concern: `01-history.ps1` (PSReadLine history), `02-exports.ps1` (env vars, PATH), `03-completion.ps1` (PSReadLine prediction), `04-fzf.ps1` (fzf env), `05-tools.ps1` (zoxide, WinGet.CommandNotFound), `06-aliases.ps1` (Set-Alias), `07-functions.ps1` (inline helpers), `08-bindings.ps1` (PSReadLine key handlers), `09-plugins.ps1` (auto-install PSGallery modules), `10-uv.ps1` (uv helpers), `99-prompt.ps1` (starship init, loaded last). `modules/work/` contains work-only modules sourced when `$env:PS_WORK = '1'`. Every `Invoke-Expression`/`Import-Module` is wrapped in `try/catch` so a missing tool never breaks the shell.
- `powershell/profile/User-Profile.ps1` is a deprecated stub. The modular profile now lives in `modules/`. Put new reusable commands in `powershell/functions/`, not in the generated loader or `User-Profile.ps1`.
- Starship themes live at the repo root in `starship/` (e.g. `nova.toml`, `nordic.toml`). The zsh installer (`zsh/install.sh`) prompts for which one to copy to `~/.config/zsh/starship.toml`; the PowerShell `powershell/profile/Set-StarshipConfig.ps1` does the same for the Windows side (supports `-Theme <name>` and `$env:PS_STARSHIP_THEME` for non-interactive use).
- `zsh/` is a copied XDG-style configuration. `zsh/install.sh` copies tracked config files into `~/.config/zsh`, manages a block in `/etc/zshenv` or `/etc/zsh/zshenv` to set `ZDOTDIR`, and excludes plugin/doc/meta files from the installed copy.
- `zsh/zsh/.zshenv` owns non-interactive environment setup and work-mode environment modules. `zsh/zsh/.zshrc` sources modules in order, with work aliases/functions enabled only when `ZSH_WORK=1` is set by `./zsh/install.sh --work`.
- `zsh/zsh/plugins.zsh` auto-clones plugins on first shell launch into `~/.config/zsh/plugins/`; do not vendor plugin checkouts into the repo.
- `er605-openwrt/` contains router-side BusyBox/POSIX shell helpers plus the guide. The flashing script locates UBI volumes named `kernel` and `kernel.b` and writes the initramfs image to both; the backup script writes MTD backups to an NTFS USB mount.
- `fonts/`, `windows-terminal/`, `extensions/`, and root Starship theme files are payload/config assets consumed manually by the scripts or external tools.
- `config/env/` holds captured Windows environment variables (user.json, system.json) plus a paths.json documenting the custom drive layout, written by `powershell/tools/Export-Env.ps1` and `powershell/tools/Import-Env.ps1`.

## Key conventions

- Admin-required PowerShell scripts either use `#requires -RunAsAdministrator` (`Set-NetworkAdapter.ps1`) or an explicit principal check with friendly prompts (`Update-WinGetPackages.ps1`, `Set-DevPackagePaths.ps1`). Match the local pattern in the file you edit.
- Interactive PowerShell scripts use concise `Read-Host` prompts, color-coded `Write-Host` status, explicit defaults in prompt text, and actionable errors. Prefer `-ErrorAction Stop` where exceptions should enter `try`/`catch`.
- Reusable PowerShell functions live in `powershell/functions/*.ps1` and commonly end with a short alias declaration, e.g. `e`, `rsb`, `upmods`, `testsocks`, `yolo`. There is no module manifest, so avoid duplicate function or alias names.
- Dependency checks are local to each script. Use `Get-Command` with a clear user-facing message for PowerShell dependencies and keep external-tool assumptions near the top of the script.
- Registry tweaks are paired `.reg` files under `registry-tweaks/dos/` and `registry-tweaks/undos/`; add matching do/undo entries when adding a tweak.
- Zsh module order matters: history/exports/completion/fzf/tools load before aliases/functions/bindings/plugins, `fast-syntax-highlighting` stays last among plugins, and Starship is initialized after plugins.
- PowerShell module order matters the same way: `modules/NN-name.ps1` files are sourced in numeric order (history → exports → completion → fzf → tools → aliases → functions → bindings → plugins → uv → prompt). Starship init (`99-prompt.ps1`) is loaded last, mirroring zsh's `prompt.zsh`.
- Work-only zsh configuration belongs under `zsh/zsh/work/`. Real Azure IDs go in the installed, git-ignored `~/.config/zsh/work/az.env`, not in tracked files.
- Work-only PowerShell configuration belongs under `powershell/profile/modules/work/`. Real Azure IDs go in the git-ignored `modules/work/04-az.env.ps1` (template is `04-az.env.ps1` tracked, real copy gitignored). Work modules are sourced only when `$env:PS_WORK = '1'`, set by `Install-Profile.ps1 -Work`.
- OpenWrt helpers should stay `/bin/sh` compatible for the router environment and avoid workstation-specific assumptions.

## PowerShell script naming

Standalone scripts and functions follow the PowerShell `Verb-Noun` convention with PascalCase, using approved verbs from `Get-Verb`. See `powershell/profile/Install-Profile.ps1` for a non-actionable exception (it's a static config file, not a script). Every script and function has comment-based help (`<# .SYNOPSIS ... #>`) at the top so `Get-Help <file>` works.
