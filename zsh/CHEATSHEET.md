# Shell Cheatsheet

> Config lives in `~/.zsh/` — edit the relevant module file and run `reload`.

---

## Keybindings

### Line editing (Emacs mode)

| Key | Action |
|-----|--------|
| `Ctrl+A` | Jump to beginning of line |
| `Ctrl+E` | Jump to end of line |
| `Ctrl+K` | Delete from cursor to end of line |
| `Ctrl+U` | Delete entire line |
| `Ctrl+W` | Delete one word backward |
| `Alt+D` | Delete one word forward |
| `Ctrl+Y` | Paste last deleted text (yank) |
| `Ctrl+L` | Clear screen |
| `Ctrl+C` | Cancel current command |
| `Ctrl+Z` | **Empty line:** run `fg` — **Non-empty:** stash line + clear screen |
| `Home` / `End` | Beginning / end of line (terminfo-portable) |
| `Delete` | Delete character under cursor |

### Word movement

| Key | Action |
|-----|--------|
| `Ctrl+Right` | Move forward one word |
| `Ctrl+Left` | Move backward one word |
| `Alt+Right` / `Alt+Left` | Same (fallback sequences) |
| `Alt+F` / `Alt+B` | Forward / backward word (emacs style) |

### History

| Key | Action |
|-----|--------|
| `↑` / `↓` | History substring search — filters by what you've already typed |
| `Ctrl+R` | fzf fuzzy history search |
| `Ctrl+P` / `Ctrl+N` | Previous / next history entry (unfiltered) |

### fzf pickers

| Key | Action |
|-----|--------|
| `Ctrl+T` | Insert file path (fd-backed, bat preview) |
| `Ctrl+R` | Fuzzy history search |
| `Alt+C` | `cd` into a subdirectory (fuzzy) |
| `Ctrl+F` | Insert file path — hidden files excluded |

### Autosuggestions

| Key | Action |
|-----|--------|
| `→` or `Ctrl+E` | Accept full suggestion |
| `Ctrl+\` | Toggle autosuggestions on/off |

### Power bindings

| Key | Action |
|-----|--------|
| `Ctrl+X Ctrl+S` | Prepend `sudo ` to current line |
| `Esc+;` | Toggle `#` comment at start of line (park without running) |
| `Ctrl+Z` (empty line) | Resume last suspended job (`fg`) |
| `Tab` / `Shift+Tab` | Next / previous completion |

---

## Navigation

### Directory aliases

| Alias | Action |
|-------|--------|
| `-` | `cd -` — jump to previous directory |
| `1`–`9` | Jump to dirstack position (`cd -1` through `cd -9`) |
| `dirh` | `dirs -v` — show numbered dirstack |
| `cda` | `cd $ASTRA_HOME` |
| `astra` | `cd $ASTRA_HOME/Common-Automation` |
| `reload` | `exec zsh -l` — restart shell, reload config |
| `cls` | `clear` |

### Global dot-dot aliases

| Alias | Expands to |
|-------|-----------|
| `..2` | `../..` |
| `..3` | `../../..` |
| `..4` | `../../../..` |
| `..5` | `../../../../..` |

### up function

```zsh
up 3   # cd up 3 directory levels at once
```

### zoxide (smart `cd`)

| Command | Action |
|---------|--------|
| `z foo` | Jump to most frecent dir matching `foo` |
| `zi` | Interactive fzf directory picker (all frecent) |
| `z -` | Previous directory |

### lf (terminal file manager)

| Command | Action |
|---------|--------|
| `lf` | Open file manager; `cd`s to wherever you quit from |
| `h` / `j` / `k` / `l` | Navigate (vim-style) |
| `q` | Quit and land in current directory |
| `Space` | Select file |
| `e` | Open file in `$EDITOR` (nvim) |
| `r` | Rename |
| `d` / `y` / `p` | Cut / copy / paste |
| `dd` | Delete |

---

## File listing (eza)

| Alias | Expands to |
|-------|-----------|
| `ls` | `eza --icons` |
| `ll` | `eza -lh --icons --git` — long + git status |
| `la` | `eza -lah --icons --git` — long + hidden + git |
| `tree` | `eza --tree --icons` — recursive tree |
| `tree -L 2` | Tree, max 2 levels deep |

---

## File viewing (bat)

| Command | Action |
|---------|--------|
| `cat file` | `bat` with syntax highlighting |
| `bat -l json file` | Force a language |
| `bat --style=plain file` | No line numbers / decorations |
| `bat --list-themes` | List available themes |
| `man <cmd>` | Man pages rendered via bat |

---

## Searching (ripgrep + fd)

| Command | Action |
|---------|--------|
| `grep pattern` | `rg --color=auto` |
| `rg pattern` | Recursive search, respects .gitignore |
| `rg -i pattern` | Case-insensitive |
| `rg -l pattern` | Files with matches only |
| `rg -t py pattern` | Limit to Python files |
| `fd name` | Find files by name (faster than find) |
| `fd -e py` | Find by extension |
| `fd -H name` | Include hidden files |
| `fd -t d name` | Find directories only |

---

## Git aliases

| Alias | Expands to |
|-------|-----------|
| `gs` | `git status --short` |
| `gst` | `git status` |
| `gb` | `git branch --show-current` |
| `gco` | `git checkout` |
| `gl` | `git log --oneline --decorate --graph -20` |
| `glog` | Full log, less-paged |
| `gadog` | All branches graph log |

### Stale branch cleanup (rsb)

```zsh
rsb              # clean stale branches in current repo
rsb ../path      # clean stale branches in another repo
rsb ~/astra      # clean all child repos under a folder
rsb -n           # dry run
rsb -D           # force delete (-D instead of -d)
```

---

## Kubernetes aliases & functions

| Command | Action |
|---------|--------|
| `k` | `kubectl` |
| `h` | `helm` |
| `tf` | `terraform` |
| `kctx` | Show current context |
| `kdev` | Switch to `aks-astra--dev` context |
| `kmodel` | Switch to `aks-astra-model` (warns) |
| `kprod` | Switch to `aks-astra-prod` (warns, read-only intent) |
| `kns <ns>` | Set default namespace for current context |
| `kcur` | Show current context name |
| `kcontexts` | List all contexts |
| `kcheck` | Context + node status |

---

## Docker aliases

| Alias | Expands to |
|-------|-----------|
| `d` | `docker` |
| `dc` | `docker compose` |

---

## Azure helpers

| Command | Action |
|---------|--------|
| `azfit` | Login to Assurant sub (browser) |
| `azdc` | Login to Assurant sub (device code — for headless) |

---

## uv helpers (Python / Astra)

| Command | Action |
|---------|--------|
| `uvdev` | `uv lock --upgrade && uv sync --dev` — update all deps locally |
| `uvci` | Lock + sync in no-sources mode (mirrors CI environment) |
| `uvtst` | Full quality gate: ruff format → ruff check → ty check → pytest → deptry |

---

## System

| Alias / Command | Action |
|-----------------|--------|
| `sysup` | `apt update + full-upgrade + autoremove + clean + autoclean` |
| `help <builtin>` | Better help for zsh builtins (e.g. `help setopt`) |
| `colormap` | Print all 256 terminal colors |
| `sedi 's/old/new/g' file` | Cross-platform `sed -i` (GNU + BSD) |
| `python` | Aliased to `python3` if unversioned cmd missing |
| `pip` | Aliased to `pip3` if unversioned cmd missing |
| `cp` | `cp -i` — prompt before overwrite |
| `mv` | `mv -i` — prompt before overwrite |
| `rm` | `rm -i` — prompt before delete |
| `df` | `df -h` — human-readable disk usage |
| `diff` | `diff --color=auto` |
| `vim` | `nvim` |

---

## WSL helpers

| Command | Action |
|---------|--------|
| `open <path/url>` | Open in Windows (wslview / cmd.exe start) |
| `explore <path>` | Open Windows Explorer at path |
| `clipcopy` | Copy stdin to Windows clipboard — `echo foo \| clipcopy` |
| `clippaste` | Paste from Windows clipboard |

---

## Plugin management

| Command | Action |
|---------|--------|
| `zplugin-update` | Pull latest for all plugins in `~/.zsh/plugins/` |

Plugins live in `~/.zsh/plugins/`. New ones auto-clone on next shell start if added to `plugins.zsh`.

---

## mise (tool version manager)

| Command | Action |
|---------|--------|
| `mise list` | Show installed tools and versions |
| `mise use node@lts` | Pin Node LTS for current directory |
| `mise use -g python@3.14` | Set global default |
| `mise ls-remote node` | List all available Node versions |
| `mise install` | Install versions declared in `.mise.toml` |
| `mise exec -- <cmd>` | Run command with mise environment |

---

## direnv

| Command | Action |
|---------|--------|
| `direnv allow` | Trust the `.envrc` in current directory |
| `direnv deny` | Revoke trust |
| `direnv reload` | Force reload after editing `.envrc` |

Auto-loads/unloads env vars when you enter/leave a directory with an `.envrc`.

---

## Config quick-reference

| File | What to edit |
|------|-------------|
| `~/.zsh/aliases.zsh` | Aliases, dirstack shortcuts, python/pip fallbacks |
| `~/.zsh/bindings.zsh` | Keybindings, ZLE widgets |
| `~/.zsh/completion.zsh` | Completion behavior, zstyles |
| `~/.zsh/exports.zsh` | Env vars, PATH, shell options, WORDCHARS |
| `~/.zsh/fzf.zsh` | fzf UI and default commands |
| `~/.zsh/functions.zsh` | WSL, Azure, k8s, git, navigation helpers |
| `~/.zsh/tools.zsh` | mise, direnv, zoxide |
| `~/.zsh/plugins.zsh` | Add/remove zsh plugins |
| `~/.zsh/prompt.zsh` | Starship init |
| `~/.zsh/starship.toml` | Selected prompt theme (copied from `starship/<name>.toml` at install time) |
| `~/.zsh/uv.zsh` | Python/uv helpers |
