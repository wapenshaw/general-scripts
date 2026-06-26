# zsh config

Modular personal zsh setup. The repo is copied into `~/.config/zsh/` on install — no symlinks, no per-user shim.

**Stack:** starship · eza · bat · fd · ripgrep · fzf · zoxide · mise · direnv · nvim · lf · nvm (lazy) · uv · keychain (work)

See [CHEATSHEET.md](./CHEATSHEET.md) for the full alias and keybinding reference.

---

## Install

```bash
cd /path/to/general-scripts
./zsh/install.sh           # base
./zsh/install.sh --work    # base + work modules (Astra / Kubernetes / Azure / SSH agent)
```

You'll be prompted for your sudo password once — install.sh appends a small block to `/etc/zshenv` (or `/etc/zsh/zshenv` on Arch) so zsh finds the config.

To remove: `./zsh/install.sh --uninstall`.

To sync changes from the repo: re-run `./install.sh [--work]`.

---

## How it works — copy + system zshenv

The install has two parts:

**1. A small block in the system zshenv** (one-time, requires sudo):

```sh
# /etc/zshenv (or /etc/zsh/zshenv on Arch) — managed by install.sh
if [[ -z "$XDG_CONFIG_HOME" ]]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
```

zsh reads this on every invocation (always, cannot be skipped), so it sets `ZDOTDIR` before any user config is loaded.

**2. A copy of the repo's `zsh/` files** at `~/.config/zsh/`. Every subsequent zsh file (`.zshenv`, `.zshrc`, `.zprofile`) is read from there.

**Why this design:**
- `~/.config/zsh/` is the standard XDG location. Nothing in `$HOME` references the repo path.
- No symlinks at all — repo and config dir are independent.
- Re-running `install.sh` re-syncs the copy from the repo. The repo is the source of truth; `~/.config/zsh/` is the installed snapshot.
- Plugins still auto-clone on first launch into `~/.config/zsh/plugins/`. They survive re-runs of install.sh (the copy step skips `plugins/`).
- Work modules toggle via `$ZSH_WORK=1` in the installed `.zshenv` — install.sh adds or removes that line based on the `--work` flag.

### Sourcing order

1. `/etc/zshenv` — sets `ZDOTDIR=$XDG_CONFIG_HOME/zsh` (system, immutable)
2. `~/.config/zsh/.zshenv` — sets `XDG_*_HOME`, `STARSHIP_CONFIG`, sources work env
3. `~/.config/zsh/.zprofile` (login shells) — shared SSH agent
4. `~/.config/zsh/.zshrc` — sources every module in order, then starship

---

## Module files

| File | Owns |
|------|------|
| `.zshenv` | XDG dirs, Starship path, Cargo, work env |
| `.zprofile` | Login-shell SSH agent (work only) |
| `.zshrc` | Orchestrator — sources all modules in order |
| `aliases.zsh` | Aliases + dirstack shortcuts |
| `bindings.zsh` | Keybindings + ZLE widgets |
| `completion.zsh` | compinit, zstyles, fuzzy matching |
| `exports.zsh` | PATH, env vars, shell options |
| `fzf.zsh` | fzf UI, fd backend, bat preview |
| `functions.zsh` | WSL, git, navigation helpers (general) |
| `history.zsh` | History options + XDG state path |
| `nvm.zsh` | Lazy-loaded NVM |
| `plugins.zsh` | Plugin manager + auto-install |
| `prompt.zsh` | Starship init |
| `tools.zsh` | mise, direnv, zoxide |
| `uv.zsh` | uvdev / uvci / uvtst helpers |
| `starship.toml` | Prompt config (Nerd Font required) |
| `work/` | Work-only modules (aliases, functions, exports, ssh-agent, az.env template) |

---

## Plugins

Auto-cloned on first shell start via `_zplugin_load`. Update all with `zplugin-update`.

| Plugin | Purpose |
|--------|---------|
| `zsh-autosuggestions` | Fish-style inline suggestions |
| `zsh-history-substring-search` | Filter history by prefix (↑/↓) |
| `fast-syntax-highlighting` | Command syntax highlighting |

---

## Tool install

This config uses: `zsh` `eza` `bat` `fd` `ripgrep` `fzf` `zoxide` `starship` `mise` `direnv` `neovim` `lf` `uv` `bun` (+ `keychain` for work mode).

### Fedora

```bash
# System packages — Fedora names fd as 'fd-find' (binary is `fd`), so no symlink needed
sudo dnf install -y zsh eza bat fd-find ripgrep fzf direnv neovim keychain

# Ensure ~/.local/bin exists and is in PATH (needed for curl-installed tools)
mkdir -p ~/.local/bin
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Starship, mise, uv install to ~/.local/bin by default — no sudo
curl -sS https://starship.rs/install.sh | sh
curl https://mise.run | sh
curl -LsSf https://astral.sh/uv/install.sh | sh

# lf — Fedora doesn't ship it; use the Go install (one-time, needs Go)
sudo dnf install -y golang && go install github.com/gokcehan/lf@latest
# Or grab a prebuilt binary: https://github.com/gokcehan/lf/releases

# bun (used for some completions)
curl -fsSL https://bun.sh/install | bash
```

Add `export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"` to your environment (in `/etc/zshenv` or `~/.zshenv`) so the Go-installed `lf` and curl-installed tools are found on every shell start.

### Ubuntu / WSL

```bash
# System packages. NOTE: Ubuntu's `bat` package installs `batcat`; `fd-find` installs `fdfind`.
sudo apt install -y zsh eza bat fd-find ripgrep fzf direnv neovim keychain

# Make ~/.local/bin exist before symlinking into it (CRITICAL on fresh WSL)
mkdir -p ~/.local/bin
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Symlink Ubuntu's renamed binaries so the config's `bat` and `fd` calls work
ln -sf "$(command -v batcat)" ~/.local/bin/bat
ln -sf "$(command -v fdfind)" ~/.local/bin/fd

# Starship, mise, uv install to ~/.local/bin
curl -sS https://starship.rs/install.sh | sh
curl https://mise.run | sh
curl -LsSf https://astral.sh/uv/install.sh | sh

# zoxide
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

# lf — Ubuntu doesn't ship it
sudo apt install -y golang-go && go install github.com/gokcehan/lf@latest
# Or grab a prebuilt binary: https://github.com/gokcehan/lf/releases

# bun (used for some completions)
curl -fsSL https://bun.sh/install | bash
```

Add `export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"` to your environment so the Go-installed `lf` and curl-installed tools are found on every shell start.

### WSL-specific gotchas

- **`~/.local/bin` does not exist on a fresh WSL install.** The rad-zsh README's `ln -s $(which batcat) ~/.local/bin/bat` fails silently if you skip the `mkdir -p`. The commands above always create it first.
- **`~/.local/bin` is not always in `$PATH`** on fresh WSL. The `case` block above adds it for the current session; the export at the end of each section makes it persistent.
- **starship/mise install to `~/.local/bin`**, which won't be on PATH until you put it there. New shells will work after that one-time export.
- **Network access in WSL** — these installers all use `curl` over HTTPS. Works through WSL's NAT; no special config needed.
- **Avoid `curl ... | sh` from `main` branches.** If you want reproducibility, pin to a tag (e.g. `https://github.com/ajeetdsouza/zoxide/releases/latest/download/install.sh`). The commands above use the official installer scripts which are stable enough for personal use.
- **`fd-find` vs `fdfind` on Ubuntu** — the package is `fd-find`, the binary is `fdfind`. Fedora's package is `fd-find` but the binary is `fd`. Different naming, same problem solved differently.
- **Snap installs of `bat` on Ubuntu 22.04+** are sandboxed and don't put `batcat` on PATH for WSL. Use `apt install bat` instead.

### Verify after install

```bash
for cmd in zsh eza bat fd rg fzf zoxide starship mise direnv nvim lf uv bun; do
  command -v "$cmd" >/dev/null 2>&1 && echo "  ✓ $cmd" || echo "  ✗ $cmd"
done
```
