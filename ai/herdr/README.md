# Herdr Workspace & Plugin Setup

Portable configuration and plugin setup for [Herdr](https://herdr.dev) — the terminal workspace manager for AI coding agents.

This directory maintains personal preferences, plugin configurations, and setup scripts to deploy configs, and install the official Theme Picker, Auto Title, Radar and Memex plugins.

Everything Herdr-related lives here: the shared defaults and plugin configs apply
on Windows, macOS and Linux, and the customized WSL profile (Ayu Dark, Radar
layout, recovery patches) is an overlay in [wsl/](wsl/README.md). The installers
below deploy the shared defaults, not that WSL overlay; follow the WSL guide when
applying those preferences.
Read [../AGENTS.md](../AGENTS.md) first, and keep work-only configuration local.

## Layout

```
ai/herdr/
├── config.toml                         # Herdr core configuration (UI, theme, keybindings)
├── config.env                          # Auto Title preferences (also synced into plugins/config/herdr.auto-title/)
├── plugins/config/                     # Plugin-specific configuration files
│   ├── hhdebb.herdr-radar/             # Radar settings and title render hook
│   └── nicosuave.memex/                # Memex plugin settings (macOS/Linux only)
├── memex/config.toml                   # Memex's own config → ~/.memex/config.toml (macOS/Linux only)
├── wsl/                                # WSL overlay: Ayu Dark config, patches, Windows Terminal profile
├── install.sh / backup.sh              # macOS / Linux installer and backup
└── Install-HerdrConfig.ps1 / Backup-HerdrConfig.ps1   # PowerShell 7 installer and backup
```

## Quick Start

### Windows (PowerShell 7)

```powershell
# Preview changes
pwsh -File ./ai/herdr/Install-HerdrConfig.ps1 -WhatIf

# Deploy configuration, install auto-title and the theme picker, and configure agent integrations
pwsh -File ./ai/herdr/Install-HerdrConfig.ps1

# Link a local auto-title checkout instead of the official release (-SkipBuild reuses its compiled binary)
pwsh -File ./ai/herdr/Install-HerdrConfig.ps1 -PluginDir Z:\Personal\herdr-auto-title -SkipBuild

# Backup live Herdr and plugin configs from your system into this repo
pwsh -File ./ai/herdr/Backup-HerdrConfig.ps1
```

### macOS / Linux

```bash
# Deploy Herdr configuration, plugins, and integrations
bash ./ai/herdr/install.sh

# Backup live Herdr and plugin configs from your system into this repo
bash ./ai/herdr/backup.sh
```

## Components

### 1. Herdr Configuration (`config.toml`)
Deploys to `%APPDATA%\herdr\config.toml` (Windows) or `~/.config/herdr/config.toml` (Linux/macOS):
* **UI**: Ayu Dark (`[theme.custom]` over the Catppuccin base, as Theme Picker writes it), sound enabled, terminal toasts, space-sorted agent panels.
* **Keybindings** (prefix is `ctrl+a`; the client's keys apply to `--remote` and saved machines too):

  | Action | Keys |
  |---|---|
  | Previous / next workspace | `ctrl+shift+alt+up` / `ctrl+shift+alt+down` |
  | Previous / next tab | `ctrl+alt+left` / `ctrl+alt+right`, `ctrl+shift+alt+left` / `ctrl+shift+alt+right` (also `ctrl+shift+alt+h` / `l`, `prefix+p` / `n`) |
  | Previous / next agent | `ctrl+alt+up` / `ctrl+alt+down` |
  | Focus pane | `prefix+h/j/k/l` or `ctrl+alt+h/j/k/l` |
  | Theme picker | `prefix+t`, `alt+t` |
  | Cycle Radar agent order (active / recent / off) | `prefix+a` |
  | Memex sidebar | `prefix+m` (acts on macOS/Linux servers) |

  If a direct chord does nothing, the terminal or OS consumed it first (Windows Terminal leaves these free; on macOS check your terminal and tools like Rectangle).

### 2. Plugins

#### A. Theme Picker (`herdr-theme-picker`)
Installed from the official `qintmb/herdr-theme-picker` (override with `HERDR_THEME_PICKER_REPO` / `HERDR_THEME_PICKER_REF`). Since v0.10.0 it runs on Windows through the Go port (built with Go on install); macOS/Linux use the Bash picker. If a local checkout is linked, the installers warn instead of replacing it; `herdr plugin unlink herdr-theme-picker` returns to the official release. Tools such as `fzf` are found because `zsh/zsh/.zshenv` puts Homebrew on `PATH` for non-interactive shells, so a server started over SSH still sees them:
* Press **`prefix+t`** to open an interactive fuzzy picker powered by [terminalcolors.com](https://terminalcolors.com).
* Maps selected themes directly to Herdr's UI chrome and live-syncs terminal cell palettes via OSC sequences.

#### B. Auto Title (`herdr.auto-title`)
Installed from the official `kryptamine/herdr-auto-title` release (includes the Windows path fixes from PR #120):
* Managed via `config.env` (`HERDR_AUTO_TITLE_BRANCH_MAX=0`, `HERDR_AUTO_TITLE_POSITION=false`).

#### C. Radar (`hhdebb.herdr-radar`)
Installed from GitHub (`hhdebb/herdr-radar`; override with `HERDR_RADAR_REPO` / `HERDR_RADAR_REF`). Needs Node.js and works on Windows, macOS and Linux.
* Groups agents by project in the sidebar with vendor logos and a tab-bar summary.
* The installers run Radar's `configure` action after deploying `config.toml`, so its managed sidebar, tab-bar and theme blocks are written with the local paths. Keep them out of the repo `config.toml`.
* `plugins/config/hhdebb.herdr-radar/` pins `follow_appearance = false` and a `render_hook` (config-relative `title-hook.cjs`) that strips the trailing ` - GitHub Copilot` from titles. After editing the hook, restart only its daemon: `herdr plugin action invoke hhdebb.herdr-radar.state-stop`, then `...state-start`.
* Radar installs an icon font for the user; set your terminal to map it if logos show as boxes (see `herdr plugin log list --plugin hhdebb.herdr-radar`).

#### D. Memex (`nicosuave.memex`)
Installed from GitHub (`nicosuave/memex`; override with `HERDR_MEMEX_REPO` / `HERDR_MEMEX_REF`) on **macOS and Linux only**: its manifest has no Windows platform and no Windows release exists, so `Install-HerdrConfig.ps1` skips it.
* `plugins/config/nicosuave.memex/config.toml` holds the plugin settings; [`memex/config.toml`](memex/config.toml) is deployed to `~/.memex/config.toml` (embeddings off, resume into a herdr tab, agent commands resolved from the login-shell `PATH`).
* The shared config binds `nicosuave.memex.toggle` to `prefix+m`. It does nothing on a Windows server but works from a Windows client attached to a macOS/Linux server with `--remote`.

### 3. Keeping machines in sync
The installers define the plugin set: Theme Picker, Auto Title, Radar everywhere, plus Memex on macOS/Linux. They install a missing plugin but leave an installed one at its current version, so update all GitHub-installed plugins together on every machine:

```sh
herdr plugin update --yes
```

Then rerun the installer to redeploy the shared config and Radar's managed blocks. `plugins.json` is a per-machine registry with local paths and is not tracked.

### 4. Auto Title Plugin Source
The scripts run `herdr plugin install kryptamine/herdr-auto-title` (override with `HERDR_AUTO_TITLE_REPO`). Herdr builds it with Go. If it is already installed the scripts leave it alone; update with `herdr plugin update herdr.auto-title --yes`, then `herdr plugin action invoke herdr.auto-title.restart`.

* **Local development**: pass a checkout to `Install-HerdrConfig.ps1 -PluginDir <path>` (or `install.sh <path>`) to build it and register it with `herdr plugin link`. If a link is already in place the installer warns instead of replacing it; run `herdr plugin unlink herdr.auto-title` to go back to the official release.

### 5. Agent Integrations
The setup scripts automatically run `herdr integration install` for supported agent clients:
* `antigravity-cli`
* `claude`
* `codex`
* `copilot`
* `opencode`

These integrations install lightweight lifecycle hooks into each agent's config folder so Herdr's socket receives live updates on active tasks, transcripts, and agent statuses.
