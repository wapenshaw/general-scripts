#!/usr/bin/env bash
# install.sh — deploy Herdr configuration, build and link herdr-auto-title, and set up agent integrations.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

HERDR_CONFIG_DIR="$XDG_CONFIG/herdr"
if [[ "$(uname -s)" == "Darwin" && ! -d "$XDG_CONFIG/herdr" && -d "$HOME/Library/Application Support/herdr" ]]; then
    HERDR_CONFIG_DIR="$HOME/Library/Application Support/herdr"
fi
AUTOTITLE_CONFIG_DIR="$XDG_CONFIG/herdr-auto-title"

green()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m!\033[0m %s\n' "$1"; }
cyan()   { printf '\033[36m::\033[0m %s\n' "$1"; }

mkdir -p "$HERDR_CONFIG_DIR" "$AUTOTITLE_CONFIG_DIR"

cyan "Deploying Herdr config.toml..."
SOURCE_CONFIG="$SCRIPT_DIR/config.toml"
[[ ! -f "$SOURCE_CONFIG" ]] && SOURCE_CONFIG="$SCRIPT_DIR/config/config.toml"

if [[ -f "$HERDR_CONFIG_DIR/config.toml" ]]; then
    cp "$HERDR_CONFIG_DIR/config.toml" "$HERDR_CONFIG_DIR/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
fi
cp "$SOURCE_CONFIG" "$HERDR_CONFIG_DIR/config.toml"
green "Deployed config.toml to $HERDR_CONFIG_DIR"

cyan "Deploying Auto Title config.env..."
SOURCE_ENV="$SCRIPT_DIR/config.env"
[[ ! -f "$SOURCE_ENV" ]] && SOURCE_ENV="$SCRIPT_DIR/config/herdr-auto-title/config.env"

if [[ -f "$AUTOTITLE_CONFIG_DIR/config.env" ]]; then
    cp "$AUTOTITLE_CONFIG_DIR/config.env" "$AUTOTITLE_CONFIG_DIR/config.env.bak-$(date +%Y%m%d-%H%M%S)"
fi
cp "$SOURCE_ENV" "$AUTOTITLE_CONFIG_DIR/config.env"
green "Deployed config.env to $AUTOTITLE_CONFIG_DIR"

cyan "Deploying plugin-specific configs..."
if [[ -d "$SCRIPT_DIR/plugins/config" ]]; then
    mkdir -p "$HERDR_CONFIG_DIR/plugins/config"
    cp -R "$SCRIPT_DIR/plugins/config/"* "$HERDR_CONFIG_DIR/plugins/config/" 2>/dev/null || true
    # Ensure herdr-auto-title plugin config points to its canonical config.env
    mkdir -p "$HERDR_CONFIG_DIR/plugins/config/herdr.auto-title"
    ln -sf "$AUTOTITLE_CONFIG_DIR/config.env" "$HERDR_CONFIG_DIR/plugins/config/herdr.auto-title/config.env"
    green "Deployed plugin configurations"
fi

if ! command -v herdr >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        cyan "Herdr binary not found. Installing via Homebrew..."
        brew install herdr || yellow "Warning: Failed to install herdr via Homebrew"
    fi
fi

if command -v herdr >/dev/null 2>&1; then
    # 1. Install herdr-theme-picker from GitHub if not already present
    if ! herdr plugin list 2>/dev/null | grep -q "herdr-theme-picker"; then
        cyan "Installing herdr-theme-picker from GitHub (qintmb/herdr-theme-picker)..."
        herdr plugin install qintmb/herdr-theme-picker --yes || yellow "Warning: Failed to install herdr-theme-picker"
    fi
    herdr plugin enable herdr-theme-picker >/dev/null 2>&1 || true

    # 2. Build and link herdr-auto-title (auto-cloning if missing on a new machine)
    PLUGIN_DIR="${1:-}"
    if [[ -z "$PLUGIN_DIR" ]]; then
        for cand in "$HOME/Code/herdr-auto-title" "$HOME/Personal/herdr-auto-title" "Z:/Personal/herdr-auto-title" "$SCRIPT_DIR/../../herdr-auto-title"; do
            if [[ -f "$cand/herdr-plugin.toml" ]]; then
                PLUGIN_DIR="$(cd "$cand" && pwd)"
                break
            fi
        done
    fi

    if [[ -z "$PLUGIN_DIR" ]]; then
        cyan "Cloning herdr-auto-title repository to ~/Code/herdr-auto-title..."
        mkdir -p "$HOME/Code"
        if git clone https://github.com/wapenshaw/herdr-auto-title.git "$HOME/Code/herdr-auto-title"; then
            PLUGIN_DIR="$HOME/Code/herdr-auto-title"
            green "Cloned herdr-auto-title"
        else
            yellow "Warning: Failed to clone herdr-auto-title repository"
        fi
    fi

    if [[ -n "$PLUGIN_DIR" && -d "$PLUGIN_DIR" ]]; then
        if command -v go >/dev/null 2>&1; then
            cyan "Building herdr-auto-title binary in $PLUGIN_DIR..."
            (cd "$PLUGIN_DIR" && go build -o herdr-auto-title ./cmd/herdr-auto-title)
            green "Compiled herdr-auto-title"
        fi

        cyan "Linking herdr-auto-title from $PLUGIN_DIR into Herdr..."
        herdr plugin link "$PLUGIN_DIR"
        green "Linked plugin"
    else
        yellow "herdr-auto-title repository not found. Pass path or clone to ~/Code/herdr-auto-title."
    fi

    cyan "Configuring agent integrations..."
    for agent in antigravity-cli claude codex copilot opencode; do
        herdr integration install "$agent" >/dev/null 2>&1 || true
    done
    green "Configured agent integrations"

    herdr server reload-config >/dev/null 2>&1 || true
    herdr plugin action invoke herdr.auto-title.restart >/dev/null 2>&1 || true
fi

green "Herdr setup complete!"
