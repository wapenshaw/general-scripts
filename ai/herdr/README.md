# Herdr Workspace & Plugin Setup

Portable configuration and plugin setup for [Herdr](https://herdr.dev) — the terminal workspace manager for AI coding agents.

This directory maintains personal preferences, plugin configurations, and setup scripts to deploy configs and link the `herdr-auto-title` plugin.

## Layout

```
ai/herdr/
├── config.toml                         # Herdr core configuration (UI, sidebar, session, toasts)
├── config.env                          # Auto Title plugin preferences
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
bash ./ai/herdr/install.sh
```

## Components

### 1. Herdr Configuration (`config.toml`)
Deploys to `%APPDATA%\herdr\config.toml` (Windows) or `~/.config/herdr/config.toml` (Linux/macOS):
* **UI**: Top tab bar position, visible tab bar even on single tabs, 30-column sidebar, and symbol status indicators.
* **Session**: Restores agent state across session resumes.
* **Terminal**: New panes follow the current working directory (`new_cwd = "follow"`).
* **Toasts**: System notifications enabled with a 1-second delay.

### 2. Auto Title Configuration (`config.env`)
Deploys to `~/.config/herdr-auto-title/config.env`:
* `HERDR_AUTO_TITLE_POSITION=true`: Prefixes tabs with their 1-based index (`1 · `, `2 · `) matching keyboard shortcuts.
* `HERDR_AUTO_TITLE_AGENT_NAME=true`: Shows the active agent name (e.g. `agy › `, `claude › `).
* `HERDR_AUTO_TITLE_PREFER_AGENT=true`: Prioritizes agent task names over terminal shell titles.
* `HERDR_AUTO_TITLE_TRANSCRIPT=true`: Reads agent session transcripts to report live tasks.
* `HERDR_AUTO_TITLE_MAX_LENGTH=50`: Bounds title width to 50 characters.
* `HERDR_AUTO_TITLE_BRANCH_MAX=0`: Hides Git branches from tab headers (set to `12` to re-enable).

### 3. Auto Title Plugin Linking
The scripts build and link the standalone `herdr-auto-title` repository (located at `Z:\Personal\herdr-auto-title` or `~/Personal/herdr-auto-title`, or custom `-PluginDir`).
The plugin contains Windows-specific fixes that recognize shell executables (`pwsh.exe`, `powershell.exe`, `cmd.exe`) and full path strings with spaces (e.g. `C:\Program Files\PowerShell\7\pwsh.exe`), preventing idle shells from generating ugly path titles.

* **Linked Mode**: The installer uses `herdr plugin link` to register the local repository with Herdr. This ensures Herdr runs your local build and will never silently overwrite it with remote commits.

### 4. Agent Integrations
The setup scripts automatically run `herdr integration install` for supported agent clients:
* `antigravity-cli`
* `claude`
* `codex`
* `copilot`
* `opencode`

These integrations install lightweight lifecycle hooks into each agent's config folder so Herdr's socket receives live updates on active tasks, transcripts, and agent statuses.
