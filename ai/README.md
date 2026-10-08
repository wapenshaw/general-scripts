# Portable AI client setup

Claude Code, Codex, Grok CLI and OpenCode preferences are captured here for Windows,
macOS and Linux. One [MCP registry](mcp/servers.json) produces each client's native
configuration. The [OpenCode package](opencode/README.md) provides
OpenCode preferences, plugin configuration and skills.

## New machine

1. Follow the repo's platform bootstrap for shell tools, Node and uv. Install the
   AI client binaries separately. Python for these scripts is managed by uv.
2. Review the imported preferences under `config/`. They preserve this user's
   model, UI and permission choices, including Claude's `bypassPermissions`,
   Grok's `always-approve`, and OpenCode's `allow`. These are personal preferences,
   not a shared permission mode across clients.
3. Render first, then install using the commands below. The installer writes
   configurations and status lines; it does not invoke clients or authenticate.
4. Log into each client on the new machine. Restore desired plugins through that
   client's plugin manager; the [inventory](inventory.json) records observed names.
   Restart clients after configuration or environment changes.

### Windows (PowerShell 7)

```powershell
./ai/Install-AIConfig.ps1
./ai/Install-AIConfig.ps1 -Install
# Optional servers; GitHub requires GITHUB_PERSONAL_ACCESS_TOKEN in this environment
./ai/Install-AIConfig.ps1 -Install -EnableMcp github,playwright
# A subset of clients
./ai/Install-AIConfig.ps1 -Install -Clients claude,codex
```

### macOS / Linux

```bash
bash ./ai/install.sh
bash ./ai/install.sh --install
# Optional servers; GitHub requires GITHUB_PERSONAL_ACCESS_TOKEN
bash ./ai/install.sh --install --enable github playwright
bash ./ai/install.sh --install --clients claude codex
```

The same underlying command works on every OS:

```bash
uv run --no-project --python 3.14 ./ai/setup.py --install
```

Default rendering writes to gitignored `ai/generated/`. It uses repo preferences,
not the destination's live credentials. Inspect that directory before installing.
`--output` changes the render destination; `--home` changes the target home for
rendering/installation. To preview macOS from Windows, use
`--platform macos --home /Users/example`; never install for a different OS.

## Files and destinations

| Repo source | Destination | Handling |
| --- | --- | --- |
| `config/claude/settings.json`, `statusline.js` | `~/.claude/` | Merge preferences; resolve status-line path on target |
| `config/claude/plugins/<name>/` | `~/.claude/local-plugins/<name>/` | Copy; list in `env.CLAUDE_CODE_PLUGIN_DIRS`, keeping unmanaged entries |
| Generated Claude MCP definitions | `~/.claude.json` → `mcpServers` | Preserve account metadata and unknown servers |
| `config/codex/config.toml` | `~/.codex/config.toml` | Merge portable preferences and registry MCP entries |
| `config/codex/windows.toml` | Same Codex config, Windows only | Preserve imported Windows sandbox choice |
| `config/grok/config.toml`, `statusline.js` | `~/.grok/` | Merge preferences and registry MCP entries |
| `opencode/config/`, `package.json`, `skills/`, `themes/` | `~/.config/opencode/` | Reuse existing payload, merge main config and generated MCP entries |
| `opencode/agent-skills/` | `~/.agents/skills/` | Deploy shared agent skills |
| `mcp/servers.json` | All four native MCP formats | One place to edit endpoint/command definitions |
| `mcp/templates/windows/`, `macos/` | Reference fragments | Generated skeletons; macOS form also works on Linux |
| `inventory.json` | Documentation only | MCP/plugin names from the original machine |

Environment overrides `CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `GROK_HOME` and
`XDG_CONFIG_HOME` are respected during normal setup. A custom `CLAUDE_CONFIG_DIR`
also places Claude's `.claude.json` inside that directory. Explicit `--home`
ignores these overrides to make relocation predictable.

Install merges imported preferences while preserving unknown settings. Managed
registry server names are replaced completely, preventing stale headers/commands
from surviving a server migration. Unknown MCP servers remain. Disabled servers
are marked `enabled=false` in Codex/Grok/OpenCode; Claude's disabled managed entries
are removed because it has no equivalent server flag. TOML comments/formatting are
not preserved when its configuration is rewritten.

Before any changed destination is written, the entire change plan is backed up
under `~/.local/state/ai-config/backups/<timestamp>/`. `files.json` records each
destination, whether it existed and its numbered original copy. These are private
backups and may contain pre-existing credentials; keep them outside version control.
Restore a numbered copy to its recorded path to undo an overwrite, or remove a file
whose recorded `existed` value is false. Installation skips identical files.

## Claude Code local plugins

`config/claude/plugins/` holds function-hook plugins (Claude Code mods). Install
copies each folder to `~/.claude/local-plugins/` and points
`CLAUDE_CODE_PLUGIN_DIRS` in `settings.json` at them, so every new session loads
them without a marketplace. Check one with `claude plugin validate <folder>`.
Options go under `pluginConfigs.<name>.options` in `settings.json`.

| Plugin | What it does |
| --- | --- |
| `cache-cold-compact` | Compacts an idle session shortly before its prompt cache goes cold, so the next prompt re-caches a summary instead of the whole transcript. `/cold-compact` shows state; `/cold-compact off` pauses it for the session. Options: `ttlMinutes` (60; set 5 on the 5-minute cache), `leadMinutes` (5), `minContextTokens` (50000), `showStatus` (true). |

## Shared MCPs

| MCP | Default | Requirement / origin |
| --- | --- | --- |
| Context7 | Enabled | Imported from Grok/OpenCode; optional `CONTEXT7_API_KEY` for higher limits |
| Microsoft Learn | Enabled | Imported from Grok; public documentation endpoint |
| OpenAI Docs | Enabled | Added to make OpenAI documentation available in every client |
| xAI Docs | Enabled | Imported from Grok; public documentation endpoint |
| Playwright | Disabled | `--enable playwright`; Node/npx required |
| GitHub | Disabled | `--enable github`; `GITHUB_PERSONAL_ACCESS_TOKEN` required |

`--enable` and `--disable` override registry defaults for that invocation. To make
selection persistent across reinstalls, edit `defaultEnabled` in the registry.
Context7's optional header is omitted at render/install time if its environment
variable is absent. No environment **values** are embedded in generated configs.

GitHub now uses the [official remote MCP](https://github.com/github/github-mcp-server),
replacing the older npm server in the previous OpenCode payload. Authentication
stays in the client environment. MCP access remains subject to account permissions.
Windows stdio templates launch npx through `cmd.exe /d /c`; macOS/Linux launch npx
directly. npm packages download on first MCP startup, not during config rendering.

Each client needs its own OAuth login for OAuth-backed servers. Grok can also
discover Claude's MCPs and plugin-provided MCPs; inspect its server list to avoid
duplicate connections. Shared names align explicit entries; plugins/account
connectors are not guaranteed to expose the same tools across all clients.

The Claude default fragment includes only enabled servers. The full skeleton is
the registry; enable additional entries there or regenerate with `--enable`.

```bash
# Regenerate tracked MCP fragments after changing the registry
uv run --no-project --python 3.14 ./ai/setup.py --write-templates
```

## Secrets, local paths and plugins

- `.env.example` documents variable names; scripts do not load `.env` files.
  Put real secrets in your OS credential tooling or private environment setup.
- No `auth.json`, Claude credentials, MCP OAuth state, account databases, session
  history, project trust, browser pipe identifiers or app-managed binary paths
  were imported.
- Codex's `node_repl`, notification command and marketplace cache paths are
  managed by its desktop app and must be regenerated there on the new machine.
  Existing destination values are preserved; this package does not reconstruct them.
- Codex's enabled plugin identifiers and Grok's enabled plugins are inventory,
  not blindly enabled on a new installation. Account-specific Grok `user/<id>/...`
  identifiers and Claude's synced skill/plugin buckets are not portable payloads.
- Claude/Grok status lines use the imported JavaScript, Node and Git. Paths are
  generated per machine; Node must be available in the environment launching them.
  Grok on Windows uses a generated `.cmd` launcher to avoid error 123 when it
  treats an inline command as a filename. See [Grok status-line troubleshooting](config/grok/README.md).
- OpenCode no longer forces Windows `pwsh` on every OS. Provider/model/plugin
  preferences stay in its existing payload; provider login stays local.

## Refreshing the preference snapshot

```bash
uv run --no-project --python 3.14 ./ai/import_local.py
```

This importer targets the observed default Windows home layout for all four
clients, allowlists personal settings, captures the two status-line scripts and
records MCP/plugin names. It does not discover every project's configuration or
export arbitrary custom servers. Review the diff after refreshing. OpenCode's
observed MCP definitions are normalized to environment references; an unhandled
literal credential in the main config stops import. Add shared MCP definitions to
the registry deliberately. The existing OpenCode plugin payload matched the live
files at the initial review and was retained. Five custom OpenCode themes were
also imported and are deployed alongside that payload.

## Client checks and references

After installation and login, inspect `claude mcp list`, `codex mcp list`,
`grok mcp list` and `opencode mcp list`; use each client's UI to authenticate when
needed. Config generation does not verify network access, model availability or
MCP tools. The initial review imported preferences and generated templates without
changing the active clients or running integration tests.

- [Claude Code MCP configuration](https://code.claude.com/docs/en/mcp)
- [Codex MCP configuration](https://developers.openai.com/codex/mcp)
- [OpenCode MCP configuration](https://opencode.ai/docs/mcp-servers/)
- [OpenCode environment substitution](https://opencode.ai/docs/config/)
- Grok's installed primary documentation: `~/.grok/docs/user-guide/07-mcp-servers.md`
  and `26-config-reference.md`; the inspected CLI supports `${VAR}` in MCP fields.
