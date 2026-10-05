# macOS Fresh Workstation Setup Guide

This guide walks through setting up a brand-new Mac from scratch to recreate this exact workstation environment, including command-line tools, GUI applications, developer runtimes, configurations, and dotfiles.

---

## Quick Start on a New Mac

On a brand-new Mac, open **Terminal.app** and run:

```bash
# 1. Install Xcode Command Line Tools (required for git)
xcode-select --install

# 2. Clone this repository
mkdir -p ~/Code
git clone https://github.com/sabbineni/Scripts.git ~/Code/Scripts
cd ~/Code/Scripts

# 3. Run the stage-wise workstation setup
./macos/install.zsh
```

---

## Staged Architecture

The setup is split into **4 clean, idempotent stages**. You can run all of them at once or execute any stage independently.

```
macos/
├── Brewfile                     # Complete Homebrew bundle (taps, brews, casks, vscode)
├── install.zsh                  # Master orchestrator script (also symlinked as bootstrap.zsh)
├── stages/
│   ├── 01-environment.zsh       # Stage 1: Base Environment & Core Shell
│   ├── 02-runtimes.zsh          # Stage 2: Developer Runtimes & Toolchains
│   ├── 03-apps.zsh              # Stage 3: Applications & Package Manager
│   └── 04-data.zsh              # Stage 4: App Configurations, Dotfiles & Data
└── configs/                     # Reusable workstation application configs
    ├── ghostty/                 # Ghostty config and Cyberdream theme
    ├── linearmouse/             # LinearMouse mouse acceleration/smooth scroll
    └── karabiner/               # Karabiner-Elements keyboard profiles
```

---

### Stage 1: Base Environment & Core Shell (`01-environment.zsh`)

* **Xcode Command Line Tools**: Checks and prompts installation if missing.
* **Homebrew**: Installs Homebrew if missing and initializes `eval $(brew shellenv)` for the bootstrap session. The deployed zsh config also does this in `~/.zsh/.zshenv`, so SSH-started services (such as a Herdr server) see Homebrew tools like `fzf`.
* **Standard Directories**: Creates `~/.local/bin`, `~/.config`, `~/.local/share`, `~/.local/state`, and `~/.cache`.
* **Developer Fonts**: Copies fonts from `fonts/` into `~/Library/Fonts/` (Hack Nerd Font, FiraCode, JetBrains Mono, Geist).
* **Canonical Zsh**: Runs `zsh/install.sh --base` to deploy `~/.zsh/`, compatibility links for `.zshenv`, `.zshrc`, `.zprofile`, and Starship theme `nova`.
* **Developer macOS Defaults**:
  - Show file extensions and hidden files in Finder
  - Enable Finder pathbar and statusbar
  - Fast key repeat rates (repeat rate `2`, initial repeat `15`)
  - Expanded save and print dialogs
  - Prevent `.DS_Store` generation on network and USB volumes

```bash
./macos/install.zsh --stage=1
# or
./macos/stages/01-environment.zsh
```

---

### Stage 2: Developer Runtimes & Toolchains (`02-runtimes.zsh`)

* **Node.js & pnpm (via NVM)**:
  - Installs NVM `v0.40.8` into `~/.nvm`.
  - Installs Node.js 26 and sets it as the default alias.
  - Installs global `pnpm`.
  - Exposes `node`, `npm`, `npx`, and `pnpm` to `~/.local/bin` for POSIX shell (`/bin/sh`, `/bin/bash`) and tool compatibility.
* **Python (via uv)**:
  - Installs `uv` via Homebrew.
  - Installs Python 3.14 via `uv python install 3.14 --default`.
  - Pins Python 3.14 globally.
  - Installs Python CLI applications: `pre-commit`, `ruff`, `awscli`.
* **Rust (via rustup)**:
  - Installs the official Rust toolchain manager without mutating shell rc files.
  - Installs the `stable` toolchain.
* **Bun & Go**:
  - Installs `bun` and `go` through Homebrew.

```bash
./macos/install.zsh --stage=2
# or
./macos/stages/02-runtimes.zsh
```

---

### Stage 3: Applications & Package Manager (`03-apps.zsh`)

Installs all curated applications defined in `macos/Brewfile`:

* **Taps**: `abue-ammar/tinycast`, `janekbaraniewski/tap`
* **CLI Utilities**: `bat`, `biome`, `bun`, `direnv`, `docker`, `eza`, `fd`, `ffmpeg`, `fzf`, `gh`, `git`, `git-delta`, `github-mcp-server`, `go`, `herdr`, `hyperfine`, `jq`, `just`, `lf`, `mole`, `neovim`, `opencode`, `pandoc`, `ripgrep`, `shellcheck`, `shfmt`, `starship`, `tmux`, `tree`, `uv`, `yq`, `zoxide`, `openusage`
* **GUI Applications (Casks)**:
  - **Terminal / Dev**: `ghostty`, `docker-desktop`, `drawio`, `markedit`
  - **AI / LLM Clients**: `claude-code`, `codex`, `codexbar`, `witsy`
  - **Utilities**: `bartender`, `caffeine`, `dockdoor`, `dockey`, `iina`, `karabiner-elements`, `keepassxc`, `linearmouse`, `muesli`, `tinycast`, `updatest`
* **VS Code Extensions**: Installs extensions when the `code` CLI is available.

```bash
./macos/install.zsh --stage=3
# or
./macos/stages/03-apps.zsh
```

---

### Stage 4: App Configurations, Dotfiles & Data (`04-data.zsh`)

* **Git & GitHub**:
  - Configures `gh auth git-credential` helper for HTTPS git operations.
  - Sets `init.defaultBranch = main` and `pull.rebase = true`.
  - Checks for `user.name` and `user.email`.
* **SSH Layout**:
  - Sets up `~/.ssh` and `~/.ssh/agent` with strict `0700` permissions.
* **Ghostty Terminal**:
  - Deploys `~/.config/ghostty/config` and the `Cyberdream` theme from `macos/configs/ghostty/`.
* **Input Configurations**:
  - Deploys `~/.config/linearmouse/linearmouse.json`.
  - Deploys `~/.config/karabiner/karabiner.json`.
* **AI Tool & Agent Client Configurations**:
  - Deploys Claude Code settings with `"SHELL": "/bin/zsh"` and statusline script.
  - Deploys Codex `config.toml`.
  - Runs OpenCode configuration installer.
* **Herdr Workspace Multiplexer & Plugins**:
  - Deploys `~/.config/herdr/config.toml` (Catppuccin theme, symbol status indicators, `prefix+t` theme picker keybind).
  - Deploys `~/.config/herdr-auto-title/config.env` and plugin configurations (`usagebar`, symlinks).
  - Installs GitHub plugin `wapenshaw/herdr-theme-picker` (ref `go-side-by-side`).
  - Auto-clones `https://github.com/wapenshaw/herdr-auto-title.git` to `~/Code/herdr-auto-title`, builds the Go binary, and links it via `herdr plugin link`.
  - Configures agent integration lifecycle hooks (`antigravity-cli`, `claude`, `codex`, `copilot`, `opencode`).

```bash
./macos/install.zsh --stage=4
# or
./macos/stages/04-data.zsh
```

---

## CLI Options

| Flag | Action |
| :--- | :--- |
| `./macos/install.zsh` | Runs all 4 stages in order (complete setup) |
| `--stage=1` / `--stage=env` | Runs Stage 1 only |
| `--stage=2` / `--stage=runtimes` | Runs Stage 2 only |
| `--stage=3` / `--stage=apps` | Runs Stage 3 only |
| `--stage=4` / `--stage=data` | Runs Stage 4 only |
| `--from=2` | Resumes from Stage 2 through Stage 4 |
| `--dry-run` | Prints all planned mutating commands without executing |
| `--assurant` | Enables work/Assurant modules during shell deployment |

---

## Ongoing Maintenance

Once your Mac is set up, run the routine update script periodically:

```bash
./mac-update.zsh
```

This keeps macOS updates checked, Homebrew packages & casks upgraded, uv Python runtimes updated, Rust toolchains updated, and ensures all Node & Python binaries remain properly exposed on `$PATH`.
