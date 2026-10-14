# WSL cleanup and performance checkup — 2026-10-10

Record of one working session: why the WSL2 disk was ~35 GB, what was removed, what was
measured, what was changed, and what is still open. Written so the same pass can be repeated.

## Result

| Metric | Before | After |
|---|---|---|
| `ext4.vhdx` on Windows | 33 GiB (~35 GB) | 24-25 GB (17 GB used inside; sparse mode on) |
| Linux used space (`df /`) | 25 GB | 15-17 GB (17 GB after the Python venvs and uv cache were rebuilt) |
| Home directory | ~20 GB | ~9.8 GB |
| Copilot `session-state` | 2.5 GB | 196 MB |
| Two stale 33 GiB vhdx backup copies | present | deleted |

## Why the vhdx was 35 GB

A WSL2 `ext4.vhdx` is a grow-only virtual disk. It records the high-water mark of everything
ever written and never shrinks by itself, even after files are deleted inside Linux. Real data
was ~25 GB; the rest was freed-but-unreleased blocks. Two more 33 GiB copies sat in
`Downloads\WSL-Backup` and the OneDrive `WSL-Backup` (pre-cleanup snapshots).

## What was cleaned (Linux side)

- **Terraform provider duplicates** — one shared azurerm 4.81.0 copy in
  `~/.terraform.d/plugin-cache`, symlinked into the four projects that pinned it. `terraform
  validate` re-checked afterwards.
- **npx cache** (`~/.npm/_npx`), **Azure MCP extractions** (`~/.net/azmcp`), old Claude Code
  binaries (kept the 2 newest) — all skipped when a running process used them.
- **Copilot CLI sessions older than 2 weeks** — 137 session directories removed. Sessions
  holding a git repo or worktree are never auto-deleted (could hold unpushed work).
- **Git worktrees inside Copilot sessions** — removed with `git worktree remove` (a hook blocks
  this for the agent, so it was run by hand with the `!` prefix). Work found in them was saved
  first: one orphaned detached-HEAD commit became a local backup branch, one docs branch was
  committed and pushed, one discarded merge attempt was dropped on purpose.
- **apt cache, journal (7 days), `/tmp` (older than 1 day), `~/.cache`** via `~/cleanup.sh` (since retired: see `./linux-update.zsh --cleanup --deep`).

## Shrinking the vhdx (Windows side)

1. Inside Linux: `sudo fstrim -av` (or `wsl -u root -- fstrim -av` from PowerShell; no sudo
   password needed). It reported 27.3 GiB "trimmed" — that is free ranges reported to the host,
   not bytes removed.
2. Administrator PowerShell: `wsl --shutdown`, wait ~10 s, then diskpart:
   `select vdisk file="<path>\ext4.vhdx"`, `attach vdisk readonly`, `compact vdisk`,
   `detach vdisk`, `exit`.
3. Make it self-maintaining: `wsl --manage <Distro> --set-sparse true` (newer builds may ask
   for `--allow-unsafe`). `sparseVhd=true` in `.wslconfig` only applies to *new* distros.

The old `dd if=/dev/zero` zero-fill is unnecessary on WSL2 — `fstrim` does the job in seconds
and writes nothing. Its "No space left on device" was always the expected end signal.

## Changes made

- **`~/cleanup.sh` rewritten** (retired 2026-10-14; `./linux-update.zsh --cleanup [--deep]` in this repo replaces it) — `fstrim` instead of zero-fill; `/tmp` limited to entries older
  than a day; new in-use-aware sweeps (npx, azmcp, old Claude versions, 14+-day Copilot
  sessions); `DRY_RUN=1` lists everything without deleting or needing sudo;
  `SESSION_MAX_AGE_DAYS` sets the cutoff.
- **Bug found in that script** — step 5 wiped all of `~/.cache`, including `~/.cache/uv`. Every
  `uv sync` then re-downloaded every wheel through the corporate proxy, and the `.venv`
  directories were gone. Fixed: the sweep now keeps `uv`, `pre-commit` and `ruff`. Venvs were
  rebuilt with the workspace's `03-setup-uv-venvs.zsh`; the uv cache is back at ~1.1 GB.
- **`TF_PLUGIN_CACHE_DIR`** exported from `zsh/zsh/work/exports.zsh` (creates the directory if
  missing — Terraform errors if it does not exist), so new `terraform init` runs reuse the
  shared providers instead of re-downloading ~700 MB per project.
- **Agent-shell fixes (`zsh/zsh/exports.zsh`, `aliases.zsh`)** — when `CLAUDECODE` is set (the
  Claude Code shell), skip `NO_clobber`, the `cp`/`mv`/`rm -i` aliases, `cat=bat` and the
  `eza` aliases, and run `unsetopt nomatch`. Interactive terminals are unchanged. See "Agent
  shells" below.
- **VS Code workspace** — dropped two unneeded folders (a personal repo and a large Terraform
  test tree) and added `uv.lock` / `*.tfstate` to `search.exclude`.

## Agent shells: why commands kept failing

Claude Code builds a *shell snapshot* from the user's zsh config at session start and replays
it before every command, so interactive-only conveniences leaked into the agent's shell:

| Symptom | Cause |
|---|---|
| `zsh: file exists` on `>` | `setopt NO_clobber` |
| Whole command aborted: `no matches found` | zsh's default `nomatch` on an empty glob |
| `rm`/`cp`/`mv` silently doing nothing | `-i` aliases with no TTY to answer the prompt |
| Odd output formats | `eza -t` means `--time` (not sort by mtime); `cat=bat` adds decoration |

`nullglob` was deliberately not used: it turns `ls *.nomatch` into a bare `ls` that lists the
current directory. Turning `nomatch` off (bash-like literal passthrough) fails safely instead.
The fix applies when a *new* Claude Code session starts; check with
`[[ -o clobber ]] && echo ok; whence -w rm` (should report `command`).

Copilot CLI is not affected: its shell tool is `bash`, which never reads `~/.zsh`, has no
`rm`/`cp`/`mv`/`cat` aliases, and passes unmatched globs through literally.

## Checkups (all measured, no action needed)

- `git status` 0.00 s in every repo; DNS lookups ~0.00 s; repos live on ext4, not `/mnt/c`.
- `.wslconfig`: 16 GB RAM, 8 CPUs, 8 GB swap, `networkingMode=Consomme`, `dnsTunneling`,
  `autoMemoryReclaim=gradual`, `sparseVhd=true`. Memory use ~1 GB idle, ~3.2 GB with VS Code
  connected; swap unused.
- `/etc/wsl.conf`: `systemd=true`, `appendWindowsPath=false`, interop `enabled=true`. Because
  Windows PATH is not appended, `code` is not on the WSL PATH; the Windows-to-WSL connection
  does not need it.
- Login shell startup `zsh -lic exit`: 0.45-1.0 s (`compinit` ~100 ms of it).
- VS Code server: one build installed (671 MB), 10 extensions, ~2.7 GB total while connected;
  `ty` / Ruff / YAML servers light, the TOML language server heaviest (~414 MB).
- inotify watches 524,288; watcher/search excludes already cover `.venv`, `.terraform`,
  `.git/objects`; `search.followSymlinks` off (matters for `.terraform` provider symlinks).
- `docker` is not installed in the distro — integration tests need Docker Desktop's WSL
  integration turned on for the distro.
- rustup (1.4 GB) kept: the herdr binary is prebuilt, but rustup is needed if herdr plugins
  are ever built from source. Remove later with `rustup self uninstall`.

## VS Code findings

- **Per-repo `python-envs.pythonProjects` blocks are required for F12.** The `ty` server gets
  its interpreter from the Python / Python Environments extensions, not by discovering `.venv`
  itself. Do not remove them. `packageManager: ms-python.python:pip` is correct for uv repos —
  there is no `uv` ID (valid: pip, conda, pipenv, poetry, system); uv is used through
  `python-envs.alwaysUseUv` (default true). Go-to-definition also needs `.venv` to exist.
- **Copilot Chat is bundled** with the VS Code server and activates on `onStartupFinished`.
  Disabling it cut Python-extension activation from ~500 ms to 200-300 ms (one extension-host
  thread), at the cost of the commit-message sparkle button, which lives in the same extension
  and cannot be loaded separately.
- A theory that pytest test discovery was slowing connect was checked and **not supported**
  (no discovery processes running minutes after connecting).

## Opening the workspace from Windows VS Code

Install the WSL extension, then F1 -> **WSL: Connect to WSL**, then File -> **Open Workspace
from File...** and give the Linux path. Or:
`code --file-uri "vscode-remote://wsl+<Distro>/<path>/<name>.code-workspace"`.

## Windows-side leftover

`Downloads\WSL-Backup` still holds a ~369 MB copy of Windows-profile config (SSH keys, Azure
token cache, kubeconfig, Docker/VS Code state). It contains plaintext credentials; delete it
once the Windows move is confirmed good. The kubeconfig is the only Windows-side copy.

## Still open

- Add `vmIdleTimeout=3600000` under `[wsl2]` in `.wslconfig` so the VM is not cold-booted at
  every VS Code connect (default is ~60 s idle shutdown).
- After a cold connect, run **Developer: Show Running Extensions** and note any activation
  over ~1 s (Terraform and TOML are the likely ones).
- Confirm the agent-shell fix in a fresh Claude Code session (command above).
- The ~/.zsh files are *copies* deployed by `zsh/install.sh`; this repo's `zsh/zsh/` is the
  source of truth. Today's edits were made in both places so a redeploy does not undo them.
