# AI Coding Agent Guide

This repo is a curated toolbox of Windows-centric PowerShell scripts and a focused OpenWrt (ER605 v2) flashing helper. There is no build system or tests; productivity comes from understanding directory roles, script conventions, and privilege/dependency requirements.

## Repo Layout and Roles
- scripts/: Top-level, runnable PowerShell utilities (task-focused, interactive).
- scripts/functions/: Reusable functions and aliases merged into the PowerShell profile by the installer.
- scripts/registry-tweaks/: One-off .reg toggles (paired do/undo patterns).
- starship/: Ready-to-copy Starship prompt themes.
- fonts/: Font payloads used with the `Install-Font`/`Install-Fonts` functions.
- er605-openwrt/: Shell scripts + guide for TP-Link ER605 v2 OpenWrt flashing and MTD backup.

## Core Workflows
- Install/refresh PowerShell profile:
  - Run scripts/install-profile.ps1. It writes `$PROFILE` by concatenating scripts/my-profile.ps1 + all scripts/functions/*.ps1, then runs scripts/starship.ps1 to choose a theme.
  - After installation, functions/aliases (e.g., `e`, `rsb`, `upmods`, `testsocks`) are available in new shells.
- Winget upgrades with exclusions: scripts/winget-upgrade-all-except.ps1 prompts for interactive/batch and handles “explicit targeting” rows. Edit `$ExcludePackages` or pass `-ExcludePackages`.
- Dev caches to `Z:\Packages`: scripts/dev-packages.ps1 configures env vars (User or Machine scope) and updates PATH for Python; also runs `npm config set cache`.
- Network adapter reset + static config: scripts/network-setup.ps1 performs a clean reset, applies static IPv4, sets DNS (with DoH), enables NetBIOS, restarts adapter, then prints a succinct summary.
- Windows Search web toggle: scripts/disable-websearch.ps1 and scripts/enable-websearch.ps1 set/remove policy keys with user confirmation.
- ER605 OpenWrt: er605-openwrt/er605v2_write_initramfs.sh flashes both UBI kernel volumes; er605-openwrt/er605-mtd-backup.sh backs up MTD to an NTFS USB. See er605-openwrt/README.md.

## Conventions and Patterns
- Admin checks: Scripts either use `#requires -RunAsAdministrator` (network-setup) or explicit principal checks with friendly prompts (winget, dev-packages, registry toggles). Match the existing style when adding admin-required flows.
- Interactive UX: Use `Read-Host` and color-coded `Write-Host` messages; keep prompts concise and explicit about defaults.
- Functions vs scripts: Put reusable helpers in scripts/functions/*.ps1. The profile installer concatenates files verbatim—no module manifest is used—so avoid conflicting function/alias names across files.
- Aliases: Short, memorable aliases accompany common functions (e.g., `e` → Open-Explorer, `rsb` → Remove-StaleBranches, `upmods` → Update-Modules, `testsocks` → Test-SocksProxy).
- Error handling: Prefer try/catch for user-facing errors and `-ErrorAction Stop` when appropriate; show actionable messages.

## External Dependencies
- PowerShell 7+, WinGet, Git, curl, Python launcher (`py`), npm, Starship, zoxide, and (optionally) smartmontools (`smartctl`).
- OpenWrt flow assumes ER605 v2 with SSH access and UBI volumes `kernel` and `kernel.b`.

## File Touchpoints and Examples
- Profile content: scripts/my-profile.ps1 (PSReadLine tab-complete, `Microsoft.WinGet.CommandNotFound`, `starship`, `zoxide`).
- Add functions: create new scripts in scripts/functions/, then re-run scripts/install-profile.ps1.
- Fonts: Use functions/Install-Font.ps1 (`Install-Fonts -fontFolders "./fonts/nerd-fonts","./fonts/coding-fonts"`). The profile installer does not auto-install fonts—call the function explicitly if needed.
- Git utilities: scripts/functions/Remove-StaleBranches.ps1 (`rsb`) cleans local branches not on remote; scripts/update-git-commits.ps1 rewrites author/committer metadata and optionally force-pushes.

## Quick-Start Commands
- Set execution policy (first run): Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
- Install profile: pwsh -File ./scripts/install-profile.ps1
- Upgrade apps: pwsh -File ./scripts/winget-upgrade-all-except.ps1 -ExcludePackages Youtube,Filebot
- Dev caches → Z: (choose scope): pwsh -File ./scripts/dev-packages.ps1
- Network setup (edit adapter name first): pwsh -File ./scripts/network-setup.ps1
- OpenWrt MTD backup (on router, NTFS USB mounted at /mnt/usb): sh ./er605-openwrt/er605-mtd-backup.sh

## Guidance for Changes
- Keep scripts self-contained, interactive, and clear about admin needs.
- Reuse existing patterns for prompts, colors, and env-var handling.
- When adding new utilities, prefer functions in scripts/functions/ with optional short aliases; expose them via the profile installer.

## Contributing Scripts
- Functions: Add reusable helpers under [scripts/functions](scripts/functions). Avoid name conflicts; keep functions small and stateless; declare aliases at the end (e.g., see [scripts/functions/Open-Explorer.ps1](scripts/functions/Open-Explorer.ps1) and [scripts/functions/Remove-StaleBranches.ps1](scripts/functions/Remove-StaleBranches.ps1)). Re-run [scripts/install-profile.ps1](scripts/install-profile.ps1) to merge into `$PROFILE`.
- CLI scripts: Place runnable, task-focused utilities in [scripts](scripts). Use `Read-Host` prompts and colored `Write-Host`. Gate admin paths with `#requires -RunAsAdministrator` or the principal check pattern (see [scripts/network-setup.ps1](scripts/network-setup.ps1), [scripts/winget-upgrade-all-except.ps1](scripts/winget-upgrade-all-except.ps1), [scripts/dev-packages.ps1](scripts/dev-packages.ps1)).
- Registry toggles: Store .reg pairs under [scripts/registry-tweaks/dos](scripts/registry-tweaks/dos) and [scripts/registry-tweaks/undos](scripts/registry-tweaks/undos); pair do/undo keys (example: [scripts/registry-tweaks/dos/Remove_Edit_in_Notepad_context_menu_for_all_users.reg](scripts/registry-tweaks/dos/Remove_Edit_in_Notepad_context_menu_for_all_users.reg)).
- Dependencies: Note external tools at the top of scripts and detect them (`Get-Command`, friendly errors). Examples: [scripts/test-farm-device.ps1](scripts/test-farm-device.ps1), [scripts/winget-upgrade-all-except.ps1](scripts/winget-upgrade-all-except.ps1).
- OpenWrt: Add related helpers under [er605-openwrt](er605-openwrt) and update [er605-openwrt/README.md](er605-openwrt/README.md) with any new procedures.
