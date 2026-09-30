# CLAUDE.md

Personal Windows 11 post-install + dev-environment toolbox. No build system, no tests, no package manager — just scripts and config payloads. Single branch: `master`.

## Authoritative guides

- **Repo conventions & architecture**: [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — read this first.
- **Fresh install playbook**: [`docs/FRESH-INSTALL.md`](docs/FRESH-INSTALL.md) — 10-step ordered bootstrap.
- **Portable AI clients and shared MCPs**: [`ai/README.md`](ai/README.md) — preferences, native config generation and private backup/install flow.

## Layout

- `powershell/` — runnable utilities: `profile/` (install + startup, modular `modules/` with ordered `NN-name.ps1` files + `work/` for work mode, `Register-ProfileFunctions.ps1` lazy-loads `functions/`), `system/` (registry/network/shutdown), `tools/` (daily helpers), `diagnostics/` (probes), `functions/` (profile-loaded helpers + short aliases)
- `zsh/` — modular macOS/Linux/WSL zsh config; `install.sh` deploys to `~/.zsh`
- `macos/`, `linux/`, `mac-update.zsh` — platform bootstraps and Mac maintenance; Windows bootstrap is `powershell/tools/Install-Workstation.ps1`
- `config/env/` — desired development storage manifest (`development.json`), directory documentation and historical environment snapshots
- `ai/` — allowlisted Claude/Codex/Grok preferences, status lines and shared MCP registry; uv-managed Python generates Windows/macOS client configs and reuses the OpenCode payload
- `starship/`, `fonts/`, `windows-terminal/`, `extensions/`, `icons/` — config/asset payloads
- `opencode/` — portable OpenCode setup: `config/` payloads (secrets via env vars), `skills/` + `agent-skills/`, cross-platform installers (`Install-OpenCodeConfig.ps1`, `install.sh`)
- `registry-tweaks/` — paired `dos/` + `undos/` `.reg` files
- `er605-openwrt/` — TP-Link ER605 v2 OpenWrt flashing helpers (router-side)

## Validate before committing

```powershell
# All PowerShell scripts parse cleanly
pwsh -NoProfile -Command '$f=$false; Get-ChildItem ./powershell -Recurse -Filter *.ps1 | ForEach-Object { $t=$null;$e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e); if($e){$f=$true;$e|Format-List} }; if($f){exit 1}'
```

```bash
sh -n ./er605-openwrt/*.sh
bash -n ./zsh/install.sh ./linux/install.sh
zsh -n ./macos/install.zsh ./mac-update.zsh
zsh -n ./zsh/zsh/.zshenv ./zsh/zsh/.zprofile ./zsh/zsh/.zshrc ./zsh/zsh/*.zsh ./zsh/zsh/work/*.zsh
```

## Conventions (short)

- PowerShell: `Verb-Noun` PascalCase, approved verbs from `Get-Verb`, comment-based help at top.
- Admin scripts: `#requires -RunAsAdministrator` or explicit principal check — match the file you edit.
- New reusable functions go in `powershell/functions/*.ps1`; startup configuration goes in ordered `powershell/profile/modules/` files. Both ConsoleHost and VS Code use AllHosts.
- Registry tweaks: always add matching `dos/` + `undos/` pairs.
- Zsh module order matters (history/exports/completion/fzf/tools → aliases/functions/bindings/plugins → `fast-syntax-highlighting` last → starship init).
- No secrets in tracked files. Export/Import-Env strips `*TOKEN*`, `*SECRET*`, `*AUTH*`. Azure creds → gitignored `~/.zsh/work/az.env`.
- Conventional commits, Angular-style scope (`feat(powershell):`, `fix(zsh):`, `docs:`).
