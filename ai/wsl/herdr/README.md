# Herdr configuration and setup

`config.toml` contains the preferred keybindings, Ayu Dark palette, login Zsh
shells and Radar layout. `plugins/config/` contains user-owned Radar and Memex
settings. These are reference configs, not a live plugin registry or a backup.

## Plugins and dependencies

| Plugin source | Reference version | Dependencies |
|---|---|---|
| `kryptamine/herdr-auto-title` | 0.13.1 | Go when building from source |
| `qintmb/herdr-theme-picker` | 0.8.2 | Bash and fzf |
| `hhdebb/herdr-radar` | 1.4.4 | Node.js; patched icon font on the rendering host |
| `nicosuave/memex` | 0.27.1 | Memex executable, Bash, Git, curl, tar and jq |

For the recorded versions, install with:

```sh
herdr plugin install kryptamine/herdr-auto-title --ref 67fa3e24f319e8c88d9a55b46563d341fb055e55
herdr plugin install qintmb/herdr-theme-picker --ref 36d117d55dca91013e0519c5778397f9764428b4
herdr plugin install hhdebb/herdr-radar --ref dd42772da4b8b9e18660d653d08149c7da1d2964
herdr plugin install nicosuave/memex --ref v0.27.1
```

Inspect the installed version first; do not downgrade a working newer plugin
just to match this reference. Let Herdr manage its own registry and checkout
paths. Installation does not restore local source changes.

## Title behavior and recovery after updates

Remove only the exact trailing ` - GitHub Copilot` from Radar labels and Auto
Title tab/pane/workspace-topic labels. Preserve Claude labels and product names
within session names. Keep Copilot's native terminal-title updates enabled and
Radar's `row_label` unset so it continues using native titles.

The official Copilot SessionStart hook reports identity, not continuous titles;
editing it is not a reliable suffix fix. Auto Title 0.13.1 has no replacement
config or render hook. Recheck upstream capabilities before patching updates.

`patches/auto-title-local-changes.patch` preserves two fixes and regression tests:
Claude `custom-title` / `customTitle` transcript support, and Copilot-only suffix
removal before activity formatting/truncation. Updates overwrite these source
changes. Locate the current checkout, inspect upstream behavior, and check the
patch there:

```sh
git apply --check /path/to/ai/wsl/herdr/patches/auto-title-local-changes.patch
```

Only apply a compatible patch. If upstream changed, port missing behavior rather
than forcing old files over new ones. After applying the relevant changes:

```sh
go test ./internal/resolver ./internal/app ./internal/claude
go build -o herdr-auto-title ./cmd/herdr-auto-title
herdr plugin action invoke herdr.auto-title.restart
```

Radar's supported suffix filter is
`plugins/config/hhdebb.herdr-radar/title-hook.cjs`, referenced by its neighboring
`config.toml`. It survives updates. Keep `follow_appearance = false` to preserve
Ayu Dark.

`patches/radar-node-path.patch` records a workaround for a server started without
NVM in its PATH. It hardcodes Node v26.10.0 under `/home/heaton`; adapt it only if
the current server cannot find Node and the chosen executable exists. Updates
replace this manifest change. Prefer correct login-shell exports for a new
server; do not install system Node over an existing NVM setup.

## Applying the configuration

Preserve destination files first. Install missing dependencies/plugins and copy
the requested user plugin configs to their matching Herdr config directories.
Adapt absolute paths in the main config, Radar hook setting, and Memex resume
templates. Deploy `../memex/config.toml` to `~/.memex/config.toml`; keep embeddings
disabled and explicit working agent executable paths if the server PATH is
minimal. Use `nicosuave.memex.toggle`, not its modal palette, for the M shortcut.

Validate and reload changed main settings without terminating panes:

```sh
herdr config check
herdr server reload-config
```

The main config already contains Ayu Dark custom colors; its underlying `vesper`
theme name is not a reason to reset the palette. There is no need to copy Theme
Picker's runtime selection marker.

`windows-terminal-profile.example.json` is a generic WSL launcher/font fragment.
Merge it into the chosen profile, preserving that profile's GUID and unrelated
settings. Adapt the distribution and shell if needed. Install `JetBrains Mono
Herdr` on Windows when Windows Terminal renders the UI, not only in WSL.
Login-interactive Zsh supplies the launcher PATH; an already-running persistent
server retains its original environment.

Keep `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` absent and preserve official Claude and
Copilot SessionStart hooks. Verify live Radar and Auto Title labels, including
an unchanged Claude title. The native Copilot title may retain the suffix; Auto
Title's width limit may legitimately truncate long labels.

When the Radar hook changes, restart only its daemon: invoke
`hhdebb.herdr-radar.state-stop`, wait for successful completion, then invoke
`hhdebb.herdr-radar.state-start` and check `herdr plugin log list`. Do not stop the
Herdr server or restart user agents without permission.
