# zsh config

Modular personal zsh setup. The repo is copied into `~/.config/zsh/` on install — no symlinks, no per-user shim.

**Stack:** starship · eza · bat · fd · ripgrep · fzf · zoxide · mise · direnv · nvim · lf · uv · keychain (work)

See [CHEATSHEET.md](./CHEATSHEET.md) for the full alias and keybinding reference.

---

## Install

```bash
cd /path/to/general-scripts
./zsh/install.sh           # base
./zsh/install.sh --work    # base + work modules (Astra / Kubernetes / Azure / SSH agent)
```

You'll be prompted for your sudo password once — install.sh appends a small block to the active system zshenv (`/etc/zsh/zshenv` on Debian/Ubuntu/WSL/Arch, `/etc/zshenv` on Fedora/upstream builds) so zsh finds the config.

To remove: `./zsh/install.sh --uninstall`.

To sync changes from the repo: re-run `./install.sh [--work]`.

---

## How it works — copy + system zshenv

The install has two parts:

**1. A small block in the system zshenv** (one-time, requires sudo):

```sh
# /etc/zsh/zshenv or /etc/zshenv — managed by install.sh
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

1. System zshenv (`/etc/zsh/zshenv` or `/etc/zshenv`) — sets `ZDOTDIR=$XDG_CONFIG_HOME/zsh` (system, immutable)
2. `~/.config/zsh/.zshenv` — sets `XDG_*_HOME`, `STARSHIP_CONFIG`, sources work env
3. `~/.config/zsh/.zprofile` (login shells) — shared SSH agent
4. `~/.config/zsh/.zshrc` — sources every module in order, then starship

---

## Design choices

These are decisions baked into the config that aren't obvious from reading the file names. If something doesn't match your workflow, edit the relevant file — every choice has a clear override point.

### nvm removed — use `mise` for Node

Earlier versions of this config shipped a `nvm.zsh` that lazy-loaded NVM. It was removed. Use [mise](https://mise.jdx.dev/) for Node version management:

```bash
# In any project directory
echo 'node = "20"' > .mise.toml
mise use node@20
mise install
```

Mise handles Node, Ruby, Go, Java, and more from a single `~/.config/mise/config.toml` or per-project `.mise.toml`. It's faster than nvm (single binary shim, no shell function) and doesn't have the NVM "slow first call" tax.

If you still need NVM, you can recreate `~/.config/zsh/nvm.zsh` from the deleted file's git history (`git log --diff-filter=D -- zsh/zsh/nvm.zsh`).

### uv prevails over mise for Python

Both `mise` and `uv` are in the config. They don't conflict, but the **division of labor is**:

- **`mise` for everything except Python** — Node, Ruby, Go, etc. via `~/.config/mise/config.toml` and per-project `.mise.toml`.
- **`uv` for Python exclusively** — `uv` is purpose-built for Python, faster than `pyenv`/`python-build`, and handles venvs, package installs, lockfiles, and Python version management in one tool. It uses `uv.lock` and `pyproject.toml` instead of `requirements.txt`.

If you let mise manage Python too, you'll get duplicate Python installs and `python` resolving to whichever loaded first. Either:

- Don't put `python = "..."` in your `mise.toml` — let `uv` handle Python versions via `uv python install 3.12` or `requires-python` in `pyproject.toml`.
- Or tell mise to skip Python entirely: in `~/.config/mise/config.toml`, set `[env]` with `MISE_PYTHON=0` or use `mise settings set python_compile false`.

The `uv.zsh` module provides `uvdev`, `uvci`, `uvtst` shortcuts for the common work flows (`uv lock --upgrade && uv sync --dev` etc.).

### Why `~/.config/zsh` instead of `~/.zsh`

XDG Base Directory spec. See the [How it works](#how-it-works--copy--system-zshenv) section above for the bootstrap chain.

---

## Module files

| File | Owns |
|------|------|
| `.zshenv` | XDG dirs, Starship path, Cargo, work env |
| `.zprofile` | Login-shell SSH agent (fixed socket at `~/.ssh/agent.sock`) |
| `.zshrc` | Orchestrator — sources all modules in order |
| `aliases.zsh` | Aliases + dirstack shortcuts |
| `bindings.zsh` | Keybindings + ZLE widgets |
| `completion.zsh` | compinit, zstyles, fuzzy matching |
| `exports.zsh` | PATH, env vars, shell options |
| `fzf.zsh` | fzf UI, fd backend, bat preview |
| `functions.zsh` | WSL, git, navigation helpers (general) |
| `history.zsh` | History options + XDG state path |
| `plugins.zsh` | Plugin manager + auto-install |
| `prompt.zsh` | Starship init |
| `tools.zsh` | mise, direnv, zoxide |
| `uv.zsh` | uvdev / uvci / uvtst helpers |
| `starship.toml` | (no longer in zsh/ — selected at install time from the repo-root `starship/` folder; see [Starship themes](#starship-themes) below) |
| `work/` | Work-only modules (aliases, functions, exports, ssh-agent, az.env template) |

---

## Starship themes

Prompt themes live at the repo root in `starship/` (siblings of `zsh/`):

```
starship/
├── gruvbox-sid.toml
├── nordic.toml
├── nordic-sid.toml
├── nova.toml          ← your current boxed-prompt setup
├── pastel-powerline.toml
└── tokyo-night-toml
```

At install time `zsh/install.sh` prompts:

```
Available starship themes:
  1) gruvbox-sid
  2) nordic
  3) nordic-sid
  4) nova
  5) pastel-powerline
  6) tokyo-night

Pick a theme [1-6] (default: nova):
```

The chosen file is copied to `~/.config/zsh/starship.toml`. To skip the prompt (e.g. for scripted installs), set `ZSH_STARSHIP_THEME` before running install:

```bash
ZSH_STARSHIP_THEME=nordic ./zsh/install.sh
```

The `~/.config/zsh/.zshenv` already sets `STARSHIP_CONFIG=$ZDOTDIR/starship.toml` so the new file is picked up automatically.

To add a new theme: drop a `.toml` in `starship/`, commit, re-run `install.sh`.

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
- **WSL interop pollutes PATH with Windows tools.** When interop is on, the Windows PATH (containing `C:\Program Files\...`, etc.) gets prepended. `which python` may return a Windows binary. Workaround if you hit this: add `interop.enabled=false` to `/etc/wsl.conf` and run `wsl --shutdown` from PowerShell, then reopen.
- **Plugin auto-clone on first launch needs network.** Behind a corporate proxy, set `https_proxy` before `exec zsh -l` so the `_zplugin_load` git clones work.

### After install — required one-time steps

These are NOT done by the install scripts and the config will not work right without them:

#### 1. Set zsh as your default shell (both Linux and WSL)

Without this, opening a new terminal still runs bash. Pick the right command for your setup:

```bash
# WSL (most common) — works inside any WSL distro
chsh -s $(which zsh)

# Pure Linux (Fedora / Ubuntu) — same command, same effect
sudo chsh -s $(which zsh) $USER
```

Log out and back in (or `exec zsh -l` and reopen the terminal) for the change to take effect.

#### 2. Install a Nerd Font in Windows Terminal (WSL only)

The starship prompt uses Nerd Font glyphs (icons for git, language versions, etc.). Without a Nerd Font you'll see ⬜ boxes in the prompt.

- **Quickest:** install [Cascadia Code Nerd Font](https://github.com/ryanoasis/nerd-fonts/releases) (the version you already have is `Hack Nerd Font`).
- In Windows Terminal: Settings → Profiles → Defaults → Appearance → Font face → `Hack Nerd Font` (or whichever you installed).
- In `~/.config/starship.toml` the `os` and similar sections already use the right glyphs.

#### 3. Set Windows Terminal's default profile to WSL

If you installed the `windows-terminal/` config from this repo, it already has the SSH and PowerShell profiles. To make a new tab open your WSL distro by default:

- Windows Terminal → Settings → Startup → Default profile → choose your WSL distro (or the `santa` SSH profile you saved).
- Or edit `windows-terminal/settings.json` and set `"defaultProfile"` to the WSL profile's `guid`.

#### 4. (Optional) Pin curl|sh scripts to specific releases

The install commands use latest-stable. If you want reproducibility:

```bash
# Starship — pin to a version
curl -sS https://github.com/starship/starship/releases/latest/download/install.sh | sh -s -- -y

# zoxide — pin
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh  # main branch, but stable
# Or: download a release binary directly
```

#### 5. (Optional) WSL interop — turn off if you want pure Linux

If Windows tools leaking into WSL's PATH bothers you (e.g. `python` resolves to `C:\Python\python.exe`):

```ini
# /etc/wsl.conf
[interop]
enabled=false
```

Then from PowerShell: `wsl --shutdown`, reopen. Note: this also disables `explorer.exe .` and `clip.exe` from inside WSL.

### Verify after install

Run this in a fresh `zsh -l` to confirm everything is wired up:

```bash
for cmd in zsh eza bat fd rg fzf zoxide starship mise direnv nvim lf uv bun; do
  command -v "$cmd" >/dev/null 2>&1 && echo "  ✓ $cmd" || echo "  ✗ $cmd"
done

echo ""
echo "=== Config ==="
echo "ZDOTDIR=$ZDOTDIR"
echo "STARSHIP_CONFIG=$STARSHIP_CONFIG"
echo "XDG_STATE_HOME=$XDG_STATE_HOME"
[[ "$ZDOTDIR" == "$HOME/.config/zsh" ]] && echo "  ✓ ZDOTDIR points to XDG location" || echo "  ✗ ZDOTDIR wrong: $ZDOTDIR"
[[ "$STARSHIP_CONFIG" == "$ZDOTDIR/starship.toml" ]] && echo "  ✓ starship config wired" || echo "  ✗ starship config wrong"

echo ""
echo "=== Widgets ==="
for w in history-substring-search-up _zsh_highlight; do
  type "$w" >/dev/null 2>&1 && echo "  ✓ $w" || echo "  ✗ $w"
done

echo ""
echo "=== Functions ==="
type rsb up open 2>/dev/null | grep "is a shell" | sed 's/^/  /'
```
