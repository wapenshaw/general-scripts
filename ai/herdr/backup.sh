#!/usr/bin/env bash
# ai/herdr/backup.sh — back up local Herdr and plugin configurations into repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HERDR_CONFIG_DIR="$XDG_CONFIG/herdr"
AUTOTITLE_CONFIG_DIR="$XDG_CONFIG/herdr-auto-title"

green()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m!\033[0m %s\n' "$1"; }
cyan()   { printf '\033[36m::\033[0m %s\n' "$1"; }

cyan "Backing up Herdr core configuration..."
if [[ -f "$HERDR_CONFIG_DIR/config.toml" ]]; then
    # Radar's managed blocks hold machine paths; its configure action rewrites them on install.
    sed '/^# >>> herdr-radar/,/^# <<< herdr-radar/d' "$HERDR_CONFIG_DIR/config.toml" > "$SCRIPT_DIR/config.toml"
    green "Backed up config.toml (without Radar's managed blocks)"
else
    yellow "No config.toml found at $HERDR_CONFIG_DIR"
fi

cyan "Backing up herdr-auto-title config..."
if [[ -f "$AUTOTITLE_CONFIG_DIR/config.env" ]]; then
    cp "$AUTOTITLE_CONFIG_DIR/config.env" "$SCRIPT_DIR/config.env"
    green "Backed up config.env (herdr-auto-title)"
fi

cyan "Backing up plugin-specific configs..."
mkdir -p "$SCRIPT_DIR/plugins/config"
if [[ -d "$HERDR_CONFIG_DIR/plugins/config" ]]; then
    # Copy plugin configs, dereferencing links or preserving files.
    # herdr.auto-title only holds a link to config.env, which is backed up above.
    for plugin_dir in "$HERDR_CONFIG_DIR/plugins/config"/*; do
        if [[ -d "$plugin_dir" ]]; then
            pname="$(basename "$plugin_dir")"
            [[ "$pname" == "herdr.auto-title" ]] && continue
            mkdir -p "$SCRIPT_DIR/plugins/config/$pname"
            for f in "$plugin_dir"/*; do
                if [[ -f "$f" ]]; then
                    cp -L "$f" "$SCRIPT_DIR/plugins/config/$pname/" 2>/dev/null || true
                fi
            done
        fi
    done
    green "Backed up plugin config directories to $SCRIPT_DIR/plugins/config"
fi

cyan "Backing up Memex config..."
if [[ -f "$HOME/.memex/config.toml" ]]; then
    mkdir -p "$SCRIPT_DIR/memex"
    cp "$HOME/.memex/config.toml" "$SCRIPT_DIR/memex/config.toml"
    green "Backed up ~/.memex/config.toml"
else
    yellow "No ~/.memex/config.toml found (Memex is macOS/Linux only)"
fi

green "Herdr and plugin configs successfully backed up!"
