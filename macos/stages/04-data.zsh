#!/usr/bin/env zsh
# macos/stages/04-data.zsh — Stage 4: App Configurations, Dotfiles & Data
#
# Configures Git identity, SSH directory permissions, Ghostty terminal settings,
# input utilities (LinearMouse, Karabiner), and AI client configurations.
set -euo pipefail

STAGE_DIR="${0:A:h}"
REPO="${STAGE_DIR:h:h}"

source "$REPO/macos/lib/common.zsh"

section "Stage 4: App Configurations, Dotfiles & Data"

# 1. Git Identity & GitHub Authentication
info "Configuring Git defaults..."
if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "git config --global credential.https://github.com.helper '!/opt/homebrew/bin/gh auth git-credential'"
    print_dry "git config --global init.defaultBranch main"
else
    # Credential helper
    if command_exists gh; then
        git config --global credential.https://github.com.helper '!/opt/homebrew/bin/gh auth git-credential'
        git config --global credential.https://gist.github.com.helper '!/opt/homebrew/bin/gh auth git-credential'
        success "GitHub credential helper linked to gh"
    fi
    git config --global init.defaultBranch main
    git config --global pull.rebase true

    # Check git identity
    CURRENT_NAME="$(git config --global user.name || true)"
    CURRENT_EMAIL="$(git config --global user.email || true)"
    if [[ -z "$CURRENT_NAME" ]]; then
        warning "git user.name is not set. Run: git config --global user.name 'Your Name'"
    else
        success "git user.name: $CURRENT_NAME"
    fi
    if [[ -z "$CURRENT_EMAIL" ]]; then
        warning "git user.email is not set. Run: git config --global user.email 'your@email.com'"
    else
        success "git user.email: $CURRENT_EMAIL"
    fi
fi

# 2. SSH Directory Layout
info "Verifying SSH directory structure..."
SSH_DIR="$HOME/.ssh"
if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "mkdir -p $SSH_DIR/agent with secure permissions (0700)"
else
    mkdir -p "$SSH_DIR/agent"
    chmod 700 "$SSH_DIR" "$SSH_DIR/agent"
    [[ -f "$SSH_DIR/authorized_keys" ]] && chmod 600 "$SSH_DIR/authorized_keys"
    success "SSH directory layout and permissions configured"
fi

# 3. Ghostty Terminal Configuration
info "Deploying Ghostty terminal configuration..."
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_THEMES_DIR="$GHOSTTY_CONFIG_DIR/themes"
if [[ -d "$REPO/macos/configs/ghostty" ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "Copy Ghostty config and Cyberdream theme to $GHOSTTY_CONFIG_DIR"
    else
        mkdir -p "$GHOSTTY_THEMES_DIR"
        [[ -f "$REPO/macos/configs/ghostty/config" ]] && cp "$REPO/macos/configs/ghostty/config" "$GHOSTTY_CONFIG_DIR/config"
        [[ -f "$REPO/macos/configs/ghostty/themes/Cyberdream" ]] && cp "$REPO/macos/configs/ghostty/themes/Cyberdream" "$GHOSTTY_THEMES_DIR/Cyberdream"
        success "Ghostty config and Cyberdream theme deployed"
    fi
fi

# 4. Input Utilities (LinearMouse & Karabiner)
info "Deploying LinearMouse and Karabiner configurations..."
if [[ -d "$REPO/macos/configs/linearmouse" ]]; then
    LM_DIR="$HOME/.config/linearmouse"
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "Copy LinearMouse config to $LM_DIR"
    else
        mkdir -p "$LM_DIR"
        cp "$REPO/macos/configs/linearmouse/linearmouse.json" "$LM_DIR/linearmouse.json"
        success "LinearMouse configuration deployed"
    fi
fi

if [[ -d "$REPO/macos/configs/karabiner" ]]; then
    KB_DIR="$HOME/.config/karabiner"
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "Copy Karabiner config to $KB_DIR"
    else
        mkdir -p "$KB_DIR"
        cp "$REPO/macos/configs/karabiner/karabiner.json" "$KB_DIR/karabiner.json"
        success "Karabiner configuration deployed"
    fi
fi

# 5. AI Client Configurations (Claude Code, Codex, Herdr, OpenCode)
info "Deploying AI client configurations..."

# Claude Code
CLAUDE_DIR="$HOME/.claude"
if [[ -d "$REPO/ai/config/claude" ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "Deploy Claude Code settings and statusline to $CLAUDE_DIR"
    else
        mkdir -p "$CLAUDE_DIR"
        [[ -f "$REPO/ai/config/claude/settings.json" ]] && cp "$REPO/ai/config/claude/settings.json" "$CLAUDE_DIR/settings.json"
        [[ -f "$REPO/ai/config/claude/statusline.js" ]] && cp "$REPO/ai/config/claude/statusline.js" "$CLAUDE_DIR/statusline.js"
        success "Claude Code configurations deployed"
    fi
fi

# Codex
CODEX_DIR="$HOME/.codex"
if [[ -d "$REPO/ai/config/codex" ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "Deploy Codex config to $CODEX_DIR"
    else
        mkdir -p "$CODEX_DIR"
        [[ -f "$REPO/ai/config/codex/config.toml" ]] && cp "$REPO/ai/config/codex/config.toml" "$CODEX_DIR/config.toml"
        success "Codex configuration deployed"
    fi
fi

# 6. Herdr Workspace Multiplexer, Plugins & Integrations
info "Deploying Herdr configuration and plugins (theme-picker, auto-title)..."
if [[ -x "$REPO/ai/herdr/install.sh" ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "$REPO/ai/herdr/install.sh (deploys config.toml, instals qintmb/herdr-theme-picker, links auto-title, sets agent hooks)"
    else
        bash "$REPO/ai/herdr/install.sh" || warning "Herdr install script exited with warnings"
        success "Herdr workspace manager, plugins, and agent integrations configured"
    fi
fi

if [[ -x "$REPO/ai/opencode/install.sh" ]]; then
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "$REPO/ai/opencode/install.sh"
    else
        bash "$REPO/ai/opencode/install.sh" || warning "OpenCode install script exited with warnings"
    fi
fi

success "Stage 4: App Configurations, Dotfiles & Data complete"
