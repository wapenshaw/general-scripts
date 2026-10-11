# WSL AI configuration and setup instructions

Personal reference configs for Claude, Copilot, Herdr and Memex. This folder is
not a machine backup or an automatic installer. Agents should use
[AGENTS.md](../AGENTS.md) to configure the requested tools, whether the destination
is a personal or work environment.

These WSL-specific references are separate from `../config/` and the shared
Herdr installer defaults at `../herdr/`. The portable `../setup.py` installer
does not deploy this profile; merge its settings only for a requested WSL setup.

| Folder | Contents | Destination |
|---|---|---|
| `copilot/` | UI/model/subagent settings, Herdr hook, centered session status line | `~/.copilot/` |
| `claude/` | UI/model settings, public plugin preferences, status line and custom hooks | `~/.claude/` |
| `herdr/` | Main config, plugin configs, title-fix patches and setup instructions | `~/.config/herdr/` |
| `memex/` | Local indexing and resume settings | `~/.memex/config.toml` |

Private MCP servers, organization marketplaces, work-specific skills and project
launchers stay local. Configuring a work tool on request does not authorize
copying its configuration or instructions into this repository. Credentials,
session histories, indexes, binaries, plugin checkouts and runtime registries
are also excluded. There is no source-path/checksum snapshot manifest here.

## Preferences to preserve

Herdr uses Ctrl+A, Ayu Dark and login Zsh shells. Ctrl+Alt Up/Down navigate agents;
Left/Right navigate tabs; H/J/K/L navigate panes. Ctrl+A then M toggles Memex's
non-modal sidebar, Shift+M moves the current pane to a new tab, and T opens
Theme Picker. See [herdr/README.md](herdr/README.md) for installation and recovery.

Memex has embeddings disabled. Its resume commands use the recorded project's
directory and create a tab in the workspace where Memex is open, rather than
automatically switching to the project's workspace.

Copilot hides navigation tabs and centers the session-name status line using
the current Herdr pane width, refreshing every two seconds. Hiding navigation
does not terminate background sessions. The helper needs Python 3 and Herdr;
outside Herdr it needs a controlling TTY.

Claude terminal titles remain enabled. Its status line needs Node.js and Git.
The settings register the destructive-command guard and the official Herdr
SessionStart hook. `no-cd-guard.sh` is retained as an optional, unregistered hook;
copying it does not enable it.

The reference files retain existing model and permission preferences. Claude's
`bypassPermissions` and suppressed dangerous-mode prompt are intentional saved
choices, not permission to enable them on a different machine without asking.

## Applying a requested setup

Inspect and back up the destination first, then merge only the requested
settings. Preserve unrelated local hooks, plugins and work integrations. Some
config commands and the Radar workaround still contain `/home/heaton` or a
specific NVM version: adapt them to the destination's actual paths before use.
Do not replace entire settings files merely to apply one preference.

Deploy referenced scripts before enabling their commands. Official integration
hooks are managed by:

```sh
herdr integration install claude
herdr integration install copilot
```

Prefer the installed Herdr version's integration over blindly copying an old
hook; preserve its SessionStart registration when merging settings.

Install public plugins and dependencies only when needed for the requested
setup. Keep private services, credentials and work-only instructions in local
configuration, not this checkout. Verify changed configs and behavior, without
ending active agent sessions or stopping Herdr.
