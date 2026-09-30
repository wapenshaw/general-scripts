# Changelog

Notable changes to this personal workstation toolbox. Newest first.

## 2026-09-30

- Fixed Grok's Windows status-line startup by generating a native `.cmd` launcher
  and configuring its single path, avoiding inline command filename parsing.

- Imported portable Claude Code, Codex and Grok preferences and status lines into
  `ai/`, with one MCP registry generating native Windows/macOS definitions for
  all four clients. Reused OpenCode's existing plugin/skill payload, corrected its
  installer source paths and environment substitution, and switched its optional
  GitHub MCP to the official remote server. Login/session state stays local.

- Windows Node is managed by nvm v2 in link mode, pnpm is standalone, and uv owns
  Python interpreters and CLI environments. Removed mise from Windows setup.
- Added the desired `Z:\Packages` storage manifest, User-scope environment setup,
  private backups and explicit environment snapshot restore.
- PowerShell 7 uses one shared AllHosts profile for Windows Terminal and VS Code,
  with manifest-selected modules and setup-time plugin installation. Fixed the
  interactive VS Code `-NoExit -Command` startup path. Visual Studio activation
  is explicit via `vsdev`.
- Integrated these changes with the cross-platform bootstraps. Windows
  `-Assurant` aliases `-Work`; an omitted theme preserves existing Starship config.
- Documented migration, backups and shell troubleshooting in the
  [profile guide](powershell/profile/README.md) and
  [cleanup record](docs/POWERSHELL-SETUP-REVIEW.md).

## 2026-08-19

First-run installers for every OS, failsafe Cargo PATH, and Assurant as an
opt-in profile instead of a Linux default.

### Added

- **`macos/install.zsh`** — Mac first-run: install Homebrew if missing, curated
  CLI tools via `mac-update.zsh --bootstrap`, official rustup
  (`--no-modify-path`), then `zsh/install.sh` (personal by default).
- **`linux/install.sh`** — Linux first-run for Fedora (`dnf`) and
  Ubuntu/Debian/WSL (`apt-get`). Missing distro packages fall back to official
  user-level installers (mise, uv, starship, zoxide, rustup). A failed package
  does not abort the rest. No sudo → skip system packages, still try user-level
  tools. Then deploys zsh (personal by default).
- **`powershell/tools/Install-Workstation.ps1`** — Windows first-run: repair
  winget if needed, `Install-Essentials.ps1`, then `Install-Profile.ps1`. Drive
  layout / `Z:\Packages` still follow `docs/FRESH-INSTALL.md` steps 1–6.
- **Failsafe Cargo PATH** — zsh (`.zshenv` + `exports.zsh`) and PowerShell
  (`02-exports.ps1`) add the rustup bin dir only when `cargo` is executable
  (`~/.cargo/bin/cargo`, or `$CARGO_HOME\bin\cargo.exe` on Windows). Leftover
  `~/.cargo/env` after `rustup self uninstall` no longer keeps a dead directory
  on PATH. Interactive zsh places `~/.cargo/bin` after `~/.local/bin` and before
  Homebrew so rustup wins over a brew `rustc`.

### Changed

- **Personal is the default on every OS.** Assurant/Astra modules install only
  with `--assurant` (PowerShell: `-Assurant`). Runtime flags are
  `ZSH_ASSURANT=1` and `$env:PS_ASSURANT`. `--base` is the explicit personal
  profile.
- **`mac-update.zsh --bootstrap`** installs Xcode CLT / Homebrew when they are
  missing, then the curated brew list (now includes starship, mise, neovim, lf,
  bun) plus official rustup and uv Python 3.13.
- **README** is the multi-platform entry point (Mac / Linux / Windows), not
  Windows-only.

### Fixed

- **Windows winget repair** now downloads the official App Installer bundle to
  a temporary local file before calling `Add-AppxPackage`; the cmdlet is not
  given a remote URL directly.
- **Mac bootstrap status** no longer reports missing `uv` as a terminal
  failure before the requested bootstrap has had a chance to install it.
- **Windows orchestration status** resets and captures exit codes around each
  child script, so `-SkipPackages` cannot inherit an unrelated stale
  `$LASTEXITCODE` from the calling PowerShell session.

### Removed

- `--work`, `-Work`, `ZSH_WORK`, and `PS_WORK`. No compatibility aliases.

### Why

Rust was installed with rustup on macOS. The old hook sourced `~/.cargo/env`
whenever that file existed, so PATH could keep `~/.cargo/bin` after uninstall.
The repo is also the toolbox for Mac, Linux (zsh), and Windows (PowerShell 7) —
each OS needed its own first-run installer using brew / dnf / apt-get / winget,
and Assurant modules belong only on Assurant machines.
