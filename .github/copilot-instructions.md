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

Zsh / platform bootstrap:

```bash
./macos/install.zsh                 # macOS first-run: Homebrew + tools + zsh (personal)
./macos/install.zsh --assurant
./mac-update.zsh                    # recurring Mac maintenance
./mac-update.zsh --bootstrap        # install Homebrew if missing + curated tools

./linux/install.sh                  # Fedora/Ubuntu first-run: dnf or apt-get + zsh (personal)
./linux/install.sh --assurant
./linux/install.sh --update

./zsh/install.sh                    # config only (personal on every OS)
./zsh/install.sh --assurant
./zsh/install.sh --uninstall
```

Windows first-run (PowerShell 7):

```powershell
pwsh -File ./powershell/tools/Install-Workstation.ps1
pwsh -File ./powershell/tools/Install-Workstation.ps1 -Assurant
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

# Bash entry points
bash -n ./zsh/install.sh ./linux/install.sh

# macOS bootstrap / maintenance
zsh -n ./macos/install.zsh ./mac-update.zsh

# Single shell script
sh -n ./er605-openwrt/er605v2_write_initramfs.sh

# Zsh config modules
zsh -n ./zsh/zsh/.zshenv ./zsh/zsh/.zprofile ./zsh/zsh/.zshrc ./zsh/zsh/*.zsh ./zsh/zsh/work/*.zsh
```

## High-level architecture

- `ai/` packages portable Claude Code, Codex, Grok and OpenCode setup. `mcp/servers.json` is the shared MCP source; `setup.py` generates native formats, renders by default and merges live configuration only with `--install`, after private backups. `import_local.py` allowlists imported preferences and never copies login/session databases. OpenCode preferences/skills stay under `opencode/`. Use uv-managed Python; generated files and local secrets are gitignored. Do not vendor app-managed Codex runtime paths, browser pipes or project trust.

- `powershell/` contains runnable, task-oriented PowerShell utilities organised by intent: `profile/` (install + startup), `system/` (registry/network/shutdown tweaks), `tools/` (ad-hoc and daily helpers), `diagnostics/` (Test-* probes). `powershell/functions/` contains reusable helpers and aliases that become available through the PowerShell profile installer.
- `powershell/profile/Install-Profile.ps1` deploys local configuration, a static `Profile.ps1` loader and `installed-profile.json`. ConsoleHost and VS Code share a thin AllHosts entry point; separate host profiles are backed up and removed. Interactive `-NoExit -Command` launches must load the profile for VS Code shell integration. Modules load from the explicit manifest, work settings precede prompt initialization, and plugins deploy to `~/.local/share/powershell/Modules` during setup. Startup performs no downloads. See `powershell/profile/README.md`.
- `powershell/profile/modules/` contains the modular profile files, each owning one concern: `01-history.ps1` (PSReadLine history), `02-exports.ps1` (env vars, PATH), `03-completion.ps1` (PSReadLine prediction), `04-fzf.ps1` (fzf env), `05-tools.ps1` (zoxide, WinGet.CommandNotFound), `06-aliases.ps1` (Set-Alias), `08-bindings.ps1` (PSReadLine key handlers), `09-plugins.ps1` (import installed plugins), `10-uv.ps1` (uv helpers), `99-prompt.ps1` (starship init, loaded last). `modules/work/` contains work-only modules sourced when `$env:PS_WORK = '1'`. Every `Invoke-Expression`/`Import-Module` is wrapped in `try/catch` so a missing tool never breaks the shell.
- Put new reusable commands in `powershell/functions/` and startup configuration in `powershell/profile/modules/`; do not add a second profile loader.
- Starship themes live at the repo root in `starship/` (e.g. `nova.toml`, `nordic.toml`). The zsh installer (`zsh/install.sh`) prompts for which one to copy to `~/.zsh/starship.toml`; the PowerShell `powershell/profile/Set-StarshipConfig.ps1` does the same for the Windows side (supports `-Theme <name>` and `$env:PS_STARSHIP_THEME` for non-interactive use).
- `macos/install.zsh` is the Mac first-run installer: it installs Xcode CLT / Homebrew when missing, runs `mac-update.zsh --bootstrap` (brew formulae + official rustup with `--no-modify-path` + uv Python), then `zsh/install.sh --base`. `mac-update.zsh` remains the recurring Mac updater.
- `linux/install.sh` is the Linux first-run installer. It detects Fedora-family (`dnf`) vs Debian/Ubuntu (`apt-get`), installs the curated CLI packages one-by-one (a missing package is a warning, not an abort), falls back to official user-level installers for mise/uv/starship/zoxide/rustup, then runs `zsh/install.sh` (personal profile by default; `--assurant` is opt-in).
- `powershell/tools/Install-Workstation.ps1` is the Windows first-run orchestrator: repair/ensure winget, `Install-Essentials.ps1`, then `Install-Profile.ps1`. Drive layout, desired storage manifest and runtime setup stay in `docs/FRESH-INSTALL.md`. `-Assurant` aliases the profile installer's `-Work`; both `PS_ASSURANT` and `PS_WORK` reflect the selected mode.
- `zsh/` is copied into the single runtime configuration directory `~/.zsh`. `zsh/install.sh` copies tracked config files there, manages a block in `/etc/zshenv` or `/etc/zsh/zshenv` to set `ZDOTDIR`, and excludes plugin/doc/meta files from the installed copy. Cargo PATH is added only when `~/.cargo/bin/cargo` is executable.
- `zsh/zsh/.zshenv` owns non-interactive environment setup and Assurant environment modules. `zsh/zsh/.zshrc` sources modules in order, with Assurant aliases/functions enabled only when `ZSH_ASSURANT=1` is set by `./zsh/install.sh --assurant`.
- `zsh/zsh/plugins.zsh` auto-clones plugins on first shell launch into `~/.zsh/plugins/`; do not vendor plugin checkouts into the repo.
- `er605-openwrt/` contains router-side BusyBox/POSIX shell helpers plus the guide. The flashing script locates UBI volumes named `kernel` and `kernel.b` and writes the initramfs image to both; the backup script writes MTD backups to an NTFS USB mount.
- `fonts/`, `windows-terminal/`, `extensions/`, and root Starship theme files are payload/config assets consumed manually by the scripts or external tools.
- `opencode/` packages the OpenCode configuration for cross-machine portability (Windows/Linux/macOS): `config/` holds sanitized config payloads (`CONTEXT7_API_KEY` and GitHub token read from env vars), `skills/` deploys to `~/.config/opencode/skills/`, and `agent-skills/` deploys to `~/.agents/skills/`. Install with `Install-OpenCodeConfig.ps1` (Windows) or `install.sh` (Linux/macOS); both support uninstall and back up changed target files before overwrite. Never commit real API keys here; the live machine's `antigravity-accounts.json` is intentionally excluded.
- `config/env/development.json` is the desired User environment/storage manifest. nvm v2 owns Node, standalone pnpm avoids Corepack, and uv owns Python. Historical snapshots under `config/env/snapshots` are backup data. Export defaults outside the repo; Import previews unless `-Apply` is explicit.

## Key conventions

- Admin-required PowerShell scripts either use `#requires -RunAsAdministrator` (`Set-NetworkAdapter.ps1`) or an explicit principal check with friendly prompts (`Update-WinGetPackages.ps1`, `Set-DevPackagePaths.ps1`). Match the local pattern in the file you edit.
- Interactive PowerShell scripts use concise `Read-Host` prompts, color-coded `Write-Host` status, explicit defaults in prompt text, and actionable errors. Prefer `-ErrorAction Stop` where exceptions should enter `try`/`catch`.
- Reusable PowerShell functions live in `powershell/functions/*.ps1` and commonly end with `Set-Alias -Name <short> -Value <Function> -Scope Global -Force` (e.g. `rsb`, `e`, `upmods`). The profile autoloader discovers these via AST and registers aliases before first load. There is no module manifest, so avoid duplicate function or alias names. File basenames need not match the function name (`Show-GitContext.ps1` → `gverify`).
- Dependency checks are local to each script. Use `Get-Command` with a clear user-facing message for PowerShell dependencies and keep external-tool assumptions near the top of the script.
- Registry tweaks are paired `.reg` files under `registry-tweaks/dos/` and `registry-tweaks/undos/`; add matching do/undo entries when adding a tweak.
- Zsh module order matters: history/exports/completion/fzf/tools load before aliases/functions/bindings/plugins, `fast-syntax-highlighting` stays last among plugins, and Starship is initialized after plugins.
- PowerShell profile loading follows `installed-profile.json`: core configuration, work settings, lazy helper registration, then prompt. Excluded modules are omitted from the manifest.
- Assurant-only zsh configuration belongs under `zsh/zsh/work/`. Real Azure IDs go in the installed, git-ignored `~/.zsh/work/az.env`, not in tracked files. Enabled only by `./zsh/install.sh --assurant`.
- Assurant-only PowerShell configuration belongs under `powershell/profile/modules/work/`. Real Azure IDs go in the git-ignored `modules/work/04-az.env.ps1` (template is `04-az.env.ps1` tracked, real copy gitignored). Assurant modules are sourced only when `$env:PS_ASSURANT = '1'`, set by `Install-Profile.ps1 -Assurant`.
- OpenWrt helpers should stay `/bin/sh` compatible for the router environment and avoid workstation-specific assumptions.

## PowerShell script naming

Standalone scripts and functions follow the PowerShell `Verb-Noun` convention with PascalCase, using approved verbs from `Get-Verb`. See `powershell/profile/Install-Profile.ps1` for a non-actionable exception (it's a static config file, not a script). Every script and function has comment-based help (`<# .SYNOPSIS ... #>`) at the top so `Get-Help <file>` works.
