# Herdr Workspace & Plugin Setup

Portable configuration and plugin setup for [Herdr](https://herdr.dev) — the terminal workspace manager for AI coding agents.

This directory maintains personal preferences, plugin configurations, and setup scripts to deploy configs and link the `herdr-auto-title` plugin.

## Layout

```
ai/herdr/
├── backup.sh                           # Exports live Herdr & plugin configs to repository
├── config.toml                         # Herdr core configuration (UI, theme, keybindings)
├── config.env                          # Auto Title plugin preferences
├── plugins.json                        # Snapshot of installed Herdr plugins and versions
├── plugins/                            # Plugin-specific configuration files
│   └── config/
│       ├── herdr.auto-title/           # Auto Title configuration
│       └── usagebar/                   # Usagebar notification and threshold settings
├── Install-HerdrConfig.ps1             # PowerShell 7 installer and linker
├── install.sh                          # macOS / Linux installer and linker
└── README.md                           # Documentation
```

## Quick Start

### Windows (PowerShell 7)

```powershell
# Preview changes
pwsh -File ./ai/herdr/Install-HerdrConfig.ps1 -WhatIf

# Deploy configuration, build and link auto-title, and configure agent integrations
pwsh -File ./ai/herdr/Install-HerdrConfig.ps1
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
* **UI**: Catppuccin theme base, sound enabled, terminal toasts, space-sorted agent panels.
* **Keybindings**: Binds `prefix+t` to `herdr-theme-picker.open` for interactive theme switching.

### 2. Plugins

#### A. Theme Picker (`herdr-theme-picker`)
Installed directly from GitHub (`qintmb/herdr-theme-picker`):
* Press **`prefix+t`** to open an interactive fuzzy picker powered by [terminalcolors.com](https://terminalcolors.com).
* Maps selected themes directly to Herdr's UI chrome and live-syncs terminal cell palettes via OSC sequences.

#### B. Auto Title (`herdr.auto-title`)
Built and linked from local checkout (`~/Code/herdr-auto-title`):
* Managed via `config.env` (`HERDR_AUTO_TITLE_BRANCH_MAX=0`, `HERDR_AUTO_TITLE_POSITION=false`).

#### C. Usagebar (`usagebar`)
Configured in `plugins/config/usagebar/config.toml` for agent quota notifications and threshold warnings.

### 3. Auto Title Plugin Linking
The scripts build and link the standalone `herdr-auto-title` repository (located at `~/Code/herdr-auto-title`, `~/Personal/herdr-auto-title`, `Z:\Personal\herdr-auto-title`, or custom `-PluginDir`).
The plugin contains platform fixes that recognize shell executables and full path strings, preventing idle shells from generating ugly path titles.

* **Linked Mode**: The installer uses `herdr plugin link` to register the local repository with Herdr. This ensures Herdr runs your local build and will never silently overwrite it with remote commits.

### 4. Agent Integrations
The setup scripts automatically run `herdr integration install` for supported agent clients:
* `antigravity-cli`
* `claude`
* `codex`
* `copilot`
* `opencode`

These integrations install lightweight lifecycle hooks into each agent's config folder so Herdr's socket receives live updates on active tasks, transcripts, and agent statuses.
