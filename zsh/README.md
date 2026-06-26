# zsh config

Modular personal zsh setup. The repo **is** the config — no symlinks, no copy step.

**Stack:** starship · eza · bat · fd · ripgrep · fzf · zoxide · mise · direnv · nvim · lf · nvm (lazy) · uv · keychain (work)

See [CHEATSHEET.md](./CHEATSHEET.md) for the full alias and keybinding reference.

---

## Install

```bash
cd /path/to/general-scripts
./zsh/install.sh           # base
./zsh/install.sh --work    # base + work modules (Astra / Kubernetes / Azure / SSH agent)
```

Open a new terminal — plugins auto-install on first launch.

To remove: `./zsh/install.sh --uninstall`.

---

## How it works — XDG without symlinks

`install.sh` writes a single small file, `~/.zshenv`, that points zsh directly at the repo. That's the entire install footprint.

```bash
# ~/.zshenv (auto-generated)
export ZDOTDIR="/path/to/general-scripts/zsh"
# export ZSH_WORK=1   # uncomment (or re-run install --work) to enable work modules
```

Three XDG env vars do the rest:

| Var | Set by | Tells zsh/tools to look in |
|-----|--------|------------------------------|
| `ZDOTDIR` | `~/.zshenv` | `zsh/` (for `.zshrc`, `.zprofile`, `.zshenv`) |
| `STARSHIP_CONFIG` | `zsh/zsh/.zshenv` | `zsh/starship.toml` |
| `XDG_*_HOME` | `zsh/zsh/.zshenv` | `~/.config`, `~/.cache`, `~/.local/share`, `~/.local/state` |

**Why no symlinks:**
- One source of truth. Edits in the repo are live, with no re-running `install.sh`.
- No `~/.zsh/` directory to keep in sync. The repo *is* `~/.zsh/`.
- `~/.zshrc` left over from an old install is silently ignored — zsh reads from `$ZDOTDIR` instead.
- Work modules toggle on/off via `$ZSH_WORK=1` in `~/.zshenv`. No separate `work/` symlink to manage.

### Sourcing order

zsh reads, in this order:
1. `/etc/zshenv` (system-wide, immutable)
2. `~/.zshenv` — sets `ZDOTDIR` (and optionally `ZSH_WORK`)
3. `$ZDOTDIR/.zshenv` — sets `XDG_*_HOME`, `STARSHIP_CONFIG`, sources work env
4. `$ZDOTDIR/.zprofile` (login shells) — sets up shared SSH agent
5. `$ZDOTDIR/.zshrc` — sources every module in order, then starship

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
