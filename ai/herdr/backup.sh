#!/usr/bin/env bash
# ai/herdr/backup.sh — back up local Herdr and plugin configurations into repository.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
HERDR_CONFIG_DIR="$XDG_CONFIG/herdr"
AUTOTITLE_CONFIG_DIR="$XDG_CONFIG/herdr-auto-title"

green()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m!\033[0m %s\n' "$1"; }
cyan()   { printf '\033[36m::\033[0m %s\n' "$1"; }

cyan "Backing up Herdr core configuration..."
if [[ -f "$HERDR_CONFIG_DIR/config.toml" ]]; then
    cp "$HERDR_CONFIG_DIR/config.toml" "$SCRIPT_DIR/config.toml"
    green "Backed up config.toml"
else
    yellow "No config.toml found at $HERDR_CONFIG_DIR"
fi

cyan "Backing up Herdr plugins manifest..."
if [[ -f "$HERDR_CONFIG_DIR/plugins.json" ]]; then
    cp "$HERDR_CONFIG_DIR/plugins.json" "$SCRIPT_DIR/plugins.json"
    green "Backed up plugins.json"
fi

cyan "Backing up herdr-auto-title config..."
if [[ -f "$AUTOTITLE_CONFIG_DIR/config.env" ]]; then
    cp "$AUTOTITLE_CONFIG_DIR/config.env" "$SCRIPT_DIR/config.env"
    green "Backed up config.env (herdr-auto-title)"
fi

cyan "Backing up plugin-specific configs..."
mkdir -p "$SCRIPT_DIR/plugins/config"
if [[ -d "$HERDR_CONFIG_DIR/plugins/config" ]]; then
    # Copy plugin configs, dereferencing links or preserving files
    for plugin_dir in "$HERDR_CONFIG_DIR/plugins/config"/*; do
        if [[ -d "$plugin_dir" ]]; then
            pname="$(basename "$plugin_dir")"
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

# Mirror to macos/configs/herdr for centralized macOS workstation snapshots
MACOS_HERDR_DIR="$REPO_DIR/macos/configs/herdr"
mkdir -p "$MACOS_HERDR_DIR"
[[ -f "$SCRIPT_DIR/config.toml" ]] && cp "$SCRIPT_DIR/config.toml" "$MACOS_HERDR_DIR/config.toml"
[[ -f "$SCRIPT_DIR/plugins.json" ]] && cp "$SCRIPT_DIR/plugins.json" "$MACOS_HERDR_DIR/plugins.json"
[[ -f "$SCRIPT_DIR/config.env" ]] && cp "$SCRIPT_DIR/config.env" "$MACOS_HERDR_DIR/config.env"
green "Mirrored snapshots to macos/configs/herdr"

green "Herdr and plugin configs successfully backed up!"
