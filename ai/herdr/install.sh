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
    # Match against a captured list: piping into grep -q under pipefail fails
    # whenever grep exits before herdr finishes writing (SIGPIPE).
    has_plugin() { grep -q "$1" <<<"$(herdr plugin list 2>/dev/null || true)"; }

    # 1. Install the official herdr-theme-picker (qintmb/herdr-theme-picker).
    #    (Homebrew on PATH for a server started over SSH is handled by
    #    zsh/zsh/.zshenv, not by the plugin.)
    THEME_REPO="${HERDR_THEME_PICKER_REPO:-qintmb/herdr-theme-picker}"
    if has_plugin "herdr-theme-picker.*local:"; then
        yellow "herdr-theme-picker is linked from a local checkout; run 'herdr plugin unlink herdr-theme-picker' to switch to the official release"
    elif has_plugin "herdr-theme-picker"; then
        green "herdr-theme-picker is already installed (update with: herdr plugin update herdr-theme-picker --yes)"
        herdr plugin enable herdr-theme-picker >/dev/null 2>&1 || true
    else
        cyan "Installing herdr-theme-picker from GitHub ($THEME_REPO)..."
        THEME_ARGS=(plugin install "$THEME_REPO" --yes)
        [[ -n "${HERDR_THEME_PICKER_REF:-}" ]] && THEME_ARGS+=(--ref "$HERDR_THEME_PICKER_REF")
        herdr "${THEME_ARGS[@]}" || yellow "Warning: Failed to install herdr-theme-picker"
        herdr plugin enable herdr-theme-picker >/dev/null 2>&1 || true
    fi

    # 2. Install the official herdr-auto-title (kryptamine/herdr-auto-title).
    #    Pass a checkout path as $1 to build and link a local copy instead.
    PLUGIN_DIR="${1:-}"
    if [[ -n "$PLUGIN_DIR" && -f "$PLUGIN_DIR/herdr-plugin.toml" ]]; then
        PLUGIN_DIR="$(cd "$PLUGIN_DIR" && pwd)"
        if command -v go >/dev/null 2>&1; then
            cyan "Building herdr-auto-title binary in $PLUGIN_DIR..."
            (cd "$PLUGIN_DIR" && go build -o herdr-auto-title ./cmd/herdr-auto-title)
            green "Compiled herdr-auto-title"
        fi
        cyan "Linking herdr-auto-title from $PLUGIN_DIR into Herdr..."
        herdr plugin link "$PLUGIN_DIR"
        green "Linked plugin"
    elif has_plugin "herdr.auto-title.*local:"; then
        yellow "herdr-auto-title is linked from a local checkout; run 'herdr plugin unlink herdr.auto-title' to switch to the official release"
    elif has_plugin "herdr.auto-title"; then
        green "herdr-auto-title is already installed (update with: herdr plugin update herdr.auto-title --yes)"
        herdr plugin enable herdr.auto-title >/dev/null 2>&1 || true
    else
        AUTO_TITLE_REPO="${HERDR_AUTO_TITLE_REPO:-kryptamine/herdr-auto-title}"
        cyan "Installing herdr-auto-title from GitHub ($AUTO_TITLE_REPO)..."
        herdr plugin install "$AUTO_TITLE_REPO" --yes || yellow "Warning: Failed to install herdr-auto-title"
        herdr plugin enable herdr.auto-title >/dev/null 2>&1 || true
    fi

    # 3. Install Herdr Radar (agent sidebar + tab bar) and apply its managed config blocks.
    RADAR_REPO="${HERDR_RADAR_REPO:-hhdebb/herdr-radar}"
    if has_plugin "hhdebb.herdr-radar"; then
        green "herdr-radar is already installed (update with: herdr plugin update hhdebb.herdr-radar --yes)"
        herdr plugin enable hhdebb.herdr-radar >/dev/null 2>&1 || true
    elif ! command -v node >/dev/null 2>&1; then
        yellow "Node.js is not in PATH; skipping herdr-radar (install Node, then rerun)"
    else
        cyan "Installing herdr-radar from GitHub ($RADAR_REPO)..."
        RADAR_ARGS=(plugin install "$RADAR_REPO" --yes)
        [[ -n "${HERDR_RADAR_REF:-}" ]] && RADAR_ARGS+=(--ref "$HERDR_RADAR_REF")
        herdr "${RADAR_ARGS[@]}" || yellow "Warning: Failed to install herdr-radar"
        herdr plugin enable hhdebb.herdr-radar >/dev/null 2>&1 || true
    fi
    # config.toml was just redeployed from the repo, so rewrite Radar's managed blocks.
    if has_plugin "hhdebb.herdr-radar"; then
        herdr plugin action invoke hhdebb.herdr-radar.configure >/dev/null 2>&1 || yellow "Warning: herdr-radar configure failed"
    fi

    # 4. Install Memex (session history desk; macOS/Linux only) and deploy its config.
    MEMEX_REPO="${HERDR_MEMEX_REPO:-nicosuave/memex}"
    if has_plugin "nicosuave.memex"; then
        green "memex plugin is already installed (update with: herdr plugin update nicosuave.memex --yes)"
        herdr plugin enable nicosuave.memex >/dev/null 2>&1 || true
    else
        cyan "Installing memex plugin from GitHub ($MEMEX_REPO)..."
        MEMEX_ARGS=(plugin install "$MEMEX_REPO" --yes)
        [[ -n "${HERDR_MEMEX_REF:-}" ]] && MEMEX_ARGS+=(--ref "$HERDR_MEMEX_REF")
        herdr "${MEMEX_ARGS[@]}" || yellow "Warning: Failed to install memex plugin"
        herdr plugin enable nicosuave.memex >/dev/null 2>&1 || true
    fi
    MEMEX_SRC="$SCRIPT_DIR/memex/config.toml"
    if [[ -f "$MEMEX_SRC" ]]; then
        mkdir -p "$HOME/.memex"
        if [[ -f "$HOME/.memex/config.toml" ]] && ! cmp -s "$MEMEX_SRC" "$HOME/.memex/config.toml"; then
            cp "$HOME/.memex/config.toml" "$HOME/.memex/config.toml.bak-$(date +%Y%m%d-%H%M%S)"
        fi
        cp "$MEMEX_SRC" "$HOME/.memex/config.toml"
        green "Deployed ~/.memex/config.toml"
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
