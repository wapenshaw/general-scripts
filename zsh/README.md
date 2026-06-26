# zsh config

Modular personal zsh setup. The repo **is** the config — no per-file symlinks, no per-user `~/.zshenv` shim.

**Stack:** starship · eza · bat · fd · ripgrep · fzf · zoxide · mise · direnv · nvim · lf · nvm (lazy) · uv · keychain (work)

See [CHEATSHEET.md](./CHEATSHEET.md) for the full alias and keybinding reference.

---

## Install

```bash
cd /path/to/general-scripts
./zsh/install.sh           # base
./zsh/install.sh --work    # base + work modules (Astra / Kubernetes / Azure / SSH agent)
```

You'll be prompted for your sudo password once — it appends a small block to `/etc/zshenv` (or `/etc/zsh/zshenv` on Arch) so zsh finds the config.

To remove: `./zsh/install.sh --uninstall`.

---

## How it works — XDG, no per-user shim

The repo's zsh config lives at `~/.config/zsh/` (the standard XDG location). The bridge between `$XDG_CONFIG_HOME` and zsh is one small block in the system zshenv file:

```sh
# /etc/zshenv (or /etc/zsh/zshenv on Arch) — managed by install.sh
if [[ -z "$XDG_CONFIG_HOME" ]]; then
    export XDG_CONFIG_HOME="$HOME/.config"
fi
if [[ -d "$XDG_CONFIG_HOME/zsh" ]]; then
    export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
fi
```

zsh reads `/etc/zshenv` on every invocation (always, cannot be skipped), so this sets `ZDOTDIR` before any user config is loaded. Every subsequent file (`.zshenv`, `.zshrc`, `.zprofile`) is then read from `$XDG_CONFIG_HOME/zsh/`.

**Why this is the right design:**
- No `~/.zshenv` to manage per user. Nothing in your home directory points at the config.
- The repo lives at the XDG path. `~/.config/zsh/.zshrc` is just the repo's `.zshrc`. Edits in the repo are live.
- A single directory symlink (`~/.config/zsh` → repo location) bridges the dotfiles repo to the XDG path. No per-file symlinks.
- Work modules toggle on/off via `$ZSH_WORK=1` in `~/.config/zsh/.zshenv`. Re-run `install.sh --work` to flip the bit in the right place.

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

### Fedora

```bash
sudo dnf install -y zsh eza bat fd-find ripgrep fzf direnv neovim keychain

curl -sS https://starship.rs/install.sh | sh
curl https://mise.run | sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`fd-find` provides the `fd` binary on Fedora; `eza`, `bat`, `fzf`, `direnv`, `neovim`, `keychain` are all directly available.

### Ubuntu / WSL

```bash
sudo apt install zsh eza bat fd-find ripgrep fzf keychain direnv neovim

# Ubuntu renames bat and fd — symlink them
ln -sf "$(which batcat)" ~/.local/bin/bat
ln -sf "$(which fdfind)" ~/.local/bin/fd

curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
curl -sS https://starship.rs/install.sh | sh
curl https://mise.run | sh
```

### lf (terminal file manager)

Either install from your package manager or grab a prebuilt binary from <https://github.com/gokcehan/lf/releases>.
