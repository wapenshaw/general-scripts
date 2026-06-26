# zsh config

Personal zsh setup for WSL Ubuntu. Modular — each concern lives in its own file.

**Stack:** starship · eza · bat · fd · ripgrep · fzf · zoxide · mise · direnv · nvim · lf · nvm (lazy) · uv

See [CHEATSHEET.md](./CHEATSHEET.md) for the full alias and keybinding reference.

---

## Install

```bash
bash ~/wapenshaw/zsh/install.sh
```

Or after cloning fresh:

```bash
git clone <your-repo-url> ~/wapenshaw
bash ~/wapenshaw/zsh/install.sh
```

Open a new terminal — plugins auto-install on first launch.

---

## How it works

`install.sh` symlinks everything into place:

| Source | Symlinked to |
|--------|-------------|
| `zshenv` | `~/.zshenv` |
| `zsh/*` | `~/.zsh/*` |

`~/.zshenv` sets `ZDOTDIR="$HOME/.zsh"`, which tells zsh to load `.zshrc`, `.zprofile` etc. from `~/.zsh/` instead of `$HOME`. Editing any file in `zsh/` edits the live config immediately — no sync step needed.

---

## Module files

| File | Owns |
|------|------|
| `.zshrc` | Orchestrator — sources all modules in order |
| `.zprofile` | Login-shell SSH agent socket setup |
| `aliases.zsh` | All aliases + dirstack shortcuts |
| `bindings.zsh` | Keybindings + ZLE widgets |
| `completion.zsh` | compinit, zstyles, fuzzy matching |
| `exports.zsh` | PATH, env vars, shell options |
| `fzf.zsh` | fzf UI, fd backend, bat preview |
| `functions.zsh` | WSL, Azure, k8s, git helpers |
| `history.zsh` | History options + XDG state path |
| `nvm.zsh` | Lazy-loaded NVM |
| `plugins.zsh` | Plugin manager + auto-install |
| `prompt.zsh` | Starship init |
| `ssh-agent.zsh` | Stable agent socket |
| `starship.toml` | Prompt config (Nerd Font required) |
| `tools.zsh` | mise, keychain, direnv, zoxide |
| `uv.zsh` | uvdev / uvci / uvtst helpers |

Add `~/.zsh/local.zsh` for machine-specific overrides — it's gitignored.

---

## Plugins

Auto-cloned on first shell start via `_zplugin_load`. Update all with `zplugin-update`.

| Plugin | Purpose |
|--------|---------|
| `zsh-autosuggestions` | Fish-style inline suggestions |
| `zsh-history-substring-search` | Filter history by prefix (↑/↓) |
| `fast-syntax-highlighting` | Command syntax highlighting |

---

## Tool install (Ubuntu / WSL)

```bash
sudo apt install zsh eza bat fd-find ripgrep fzf keychain direnv neovim

# Ubuntu renames bat and fd — symlink them
ln -sf "$(which batcat)" ~/.local/bin/bat
ln -sf "$(which fdfind)" ~/.local/bin/fd

curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
curl -sS https://starship.rs/install.sh | sh
curl https://mise.run | sh

# lf: https://github.com/gokcehan/lf/releases
```
