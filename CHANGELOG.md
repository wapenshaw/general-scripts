# Changelog

Notable changes to this personal workstation toolbox. Newest first.

## 2026-10-30

### Added

- **`cache-cold-compact` 0.2.0: `/handoff-compact [emphasis]`** compacts now with the
  handoff-document prompt passed to `$.session.compact`, so it holds when another plugin's
  `session.compact` hook runs first and the plugin's own rewrite of `/compact` is skipped.
  Re-run `Install-AIConfig.ps1 -Install` / `install.sh --install` to deploy it.

## 2026-10-14

Homebrew (Linuxbrew) on WSL owns the standalone CLI tools; Python stays with uv and
Node with nvm.

### Added

- **`linux/install.sh --wsl`** — opt-in WSL provisioning step (skipped with a notice outside WSL;
  combine with `--skip-tools --skip-zsh` to run only this). Makes `/etc/wsl.conf` carry
  `[boot] systemd=true` and `[interop] appendWindowsPath=false`, and `[user] default` when it is
  unset: shows a diff, backs the file up, writes it with sudo, leaves every other key and comment
  alone, and is a no-op when already correct. Reports `generateResolvConf=false` without a
  nameserver in `/etc/resolv.conf`, and reads (never writes) the Windows-side `.wslconfig` for
  `sparseVhd`, `vmIdleTimeout` and `dnsTunneling`. Changes apply after `wsl --shutdown`.
- **`linux/Brewfile`** — bat, eza, fd, fzf, gh, git-delta, helm, hyperfine, jq, just, k9s,
  Azure kubelogin (tap), neovim, ripgrep, shellcheck, shfmt, starship, yq, zoxide. Documents
  what is deliberately not brewed (python, node, uv, terraform, rustup, go, kubectl/docker,
  bun, direnv, system tools). `azure/kubelogin/kubelogin` is Azure's AKS plugin; homebrew-core's
  `kubelogin` is an unrelated OIDC plugin that breaks AKS kubeconfigs.
- **`linux-update.zsh`** — Linux/WSL maintenance, the counterpart of `mac-update.zsh`: lists
  (`--system`: installs) apt/dnf updates; `brew update/upgrade/autoremove/cleanup/doctor`;
  rustup; `uv self update`, `uv python upgrade`, `uv tool upgrade --all`; keeps the Azure
  kubelogin tap shallow; `--bootstrap` applies the Brewfile, rustup, uv Python 3.14 and tools;
  `--cleanup` (apt/dnf cache and unused packages, journal, rotated logs, old `/tmp`, brew/uv/npm/pip
  caches; general Linux, never wipes the uv cache or deletes sockets), `--wsl` (WSL only:
  `sudo fstrim -av` so the VHDX can shrink, plus the Windows-side steps; the read-only WSL checks,
  disk usage, `no-aaaa` and `SSL_CERT_FILE`, also print on a plain run under WSL), `--deep` (also
  `~/.cache`, npx, Azure MCP extractions, old Claude versions, idle Copilot sessions; replaces
  the retired, deleted `~/cleanup.sh`), `--dry-run`. Checks that brew-owned tools resolve into Homebrew, flags leftover apt copies,
  brew python/node/bash/rust formulae and the wrong kubelogin, verifies PATH order (nvm node and
  `~/.local/bin` ahead of brew, brew ahead of `/usr/bin`), and runs WSL checks (disk, `no-aaaa`,
  `SSL_CERT_FILE`).

### Fixed

- **bash shells now see Homebrew.** bash never reads `~/.zsh`, so tools like `gh` were
  unreachable for agents that run bash (Copilot CLI) once their apt copies were gone.
  `linux/shell/brew.sh` (static, no `brew shellenv` fork; brew behind `$HOME` dirs, ahead of
  the system dirs) is deployed to `~/.config/shell/brew.sh` and sourced from `~/.profile` and
  `~/.bashrc` by `linux/install.sh` (also `--bash-only`). `linux-update.zsh` checks it.
  Processes started earlier keep their old PATH until restarted.

### Changed

- **Redeploying the zsh config is now safe.** `zsh/zsh/` carries what only the live `~/.zsh` had:
  the WSL `RES_OPTIONS=no-aaaa` DNS fix (`.zshenv`), the `/mnt/c/Windows` helper paths for
  `open`/`explore`/`clipcopy`/`clippaste` (`functions.zsh`) and the brew-behind-`$HOME` PATH step
  (`.zshenv`, re-applied in `.zprofile`). `zsh/install.sh --assurant` was verified in a throwaway
  `HOME`, then run for real; startup behavior (PATH, `RES_OPTIONS`, `SSL_CERT_FILE`, `sysup`,
  aliases, `CLAUDECODE` guards) is unchanged except nvm's node now leads PATH.
- **`linux/install.sh`** installs only system prerequisites natively (zsh, git, curl, build
  tools, direnv), then Homebrew and `linux/Brewfile`, the official uv/rustup/bun installers and
  uv's default Python 3.14. The apt tool catalog, the `batcat`/`fdfind` links and the mise,
  starship and zoxide fallback installers are gone.
- **`sysup`** (`zsh/zsh/aliases.zsh`) runs apt and then `brew update/upgrade/cleanup` on
  Linux; macOS is brew only.
- Deployed `~/.zsh/.zshenv` loads `brew shellenv zsh` ahead of the nvm/cargo/work blocks
  (guarded), then ends by moving brew behind everything under `$HOME` (nvm's node,
  `~/.local/bin`, cargo, bun, tfenv) and ahead of the system dirs, so brew cannot shadow uv's
  `python` or nvm's `node` even in child shells that inherit PATH. The repo `zsh/zsh/.zshenv`
  already carries its own brew block.

One auto-compact plugin, on by default in every session, with a handoff-document
summary and a status line segment.

### Changed

- **`cache-cold-compact`** now rewrites the instructions of every main-conversation
  compaction (engine threshold, `/compact`, its own timer) to a detailed handoff
  document brief (`hooks/handoff.ts`, tested); its own timed compaction passes the brief
  explicitly because a plugin's own `compact()` skips its own hook.
- **Status line** (`ai/wsl/claude/statusline.js`, `ai/config/claude/statusline.js`) shows
  `compact in 43m` / `compacting…` / `compact off` / `compacted 142k→18k`, read from
  `~/.claude/cold-compact/sessions/<session id>.json` written by the plugin; omitted when
  the plugin is not loaded.
- **`ai/wsl/claude/settings.json`** loads the plugin through `CLAUDE_CODE_PLUGIN_DIRS`
  (it was never loaded on WSL) and sets its options. The live plugin is
  `~/.claude/local-plugins/cache-cold-compact/`; `ai/config/claude/plugins/` holds a copy.

### Removed

- **keepwarm**, everywhere: the plugin, its marketplace, its `KEEPWARM_*` settings, its
  state directory and every reference in the WSL settings template and README. It pinged
  the prompt cache at its own interval while cache-cold-compact compacts at 55 minutes
  idle, so running both defeated the purpose of either.

## 2026-10-10

WSL cleanup and performance pass; agent shells no longer inherit interactive-only zsh
behavior. Full record in `docs/WSL-CLEANUP-2026-10-10.md`.

### Added

- **`docs/WSL-CLEANUP-2026-10-10.md`** — why the WSL2 vhdx grew to ~35 GB, what was cleaned,
  the fstrim + diskpart + sparse recipe, measured checkups, VS Code findings, and open items.
- **`TF_PLUGIN_CACHE_DIR`** in `zsh/zsh/work/exports.zsh` (directory created if missing) so
  Terraform shares one provider cache across projects.

### Changed

- **Agent shells stay POSIX-predictable.** When `CLAUDECODE` is set, `zsh/zsh/exports.zsh`
  skips `NO_clobber` and runs `unsetopt nomatch` (unmatched globs pass through literally), and
  `zsh/zsh/aliases.zsh` skips the `cp`/`mv`/`rm -i`, `cat=bat` and `eza` aliases. Interactive
  terminals are unchanged.

### Why

Claude Code replays a snapshot of the user's zsh config before every command, so noclobber,
`-i` aliases and zsh's abort-on-empty-glob made agent commands fail or silently do nothing.
Deployed `~/.zsh` files are copies of `zsh/zsh/`, so the fix lives here to survive a redeploy.

## 2026-10-05

- Fixed "fzf is not installed" in Herdr plugins after a reboot: a server started
  over SSH by a `herdr --remote` client runs a non-interactive `zsh -c`, which
  never read the Homebrew setup that lived only in `.zprofile`. Homebrew
  `shellenv` (Apple Silicon, Intel, Linuxbrew; guarded) now loads from
  `zsh/zsh/.zshenv`, `.zprofile` re-applies it after macOS `path_helper`, and
  `zsh/install.sh` verifies a minimal-environment `zsh -c` can find `brew`.
- `zsh/install.sh` no longer needs bash 4: it failed on macOS's stock bash 3.2
  (`local -A`), which is what a fresh Mac runs before Homebrew bash exists.
- The Herdr installer now installs the theme picker from `wapenshaw/herdr-theme-picker`
  (ref `go-side-by-side`, overridable via `HERDR_THEME_PICKER_REPO`/`_REF`) to get
  the Windows port. The plugin itself no longer guesses tool directories; the
  `.zshenv` change above is what keeps `fzf` visible.

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
