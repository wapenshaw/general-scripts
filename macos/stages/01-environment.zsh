#!/usr/bin/env zsh
# macos/stages/01-environment.zsh — Stage 1: Base Environment & Core Shell
#
# Sets up Xcode CLI tools, Homebrew, standard directories, developer fonts,
# canonical zsh configuration, and developer macOS defaults.
set -euo pipefail

STAGE_DIR="${0:A:h}"
REPO="${STAGE_DIR:h:h}"

source "$REPO/macos/lib/common.zsh"

section "Stage 1: Base Environment & Core Shell"

# 1. Xcode Command Line Tools
info "Checking Xcode Command Line Tools..."
if xcode-select -p >/dev/null 2>&1; then
    success "Xcode Command Line Tools installed ($(xcode-select -p))"
else
    info "Installing Xcode Command Line Tools..."
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "xcode-select --install"
    else
        xcode-select --install
        info "Complete the GUI installation prompt, then re-run this script."
        exit 1
    fi
fi

# 2. Homebrew
info "Checking Homebrew..."
if command_exists brew; then
    success "Homebrew is installed ($(brew --version | head -n 1))"
else
    info "Installing Homebrew..."
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

# Ensure Homebrew is active in the current session
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 3. Base directory layout
info "Setting up base directories..."
BASE_DIRS=(
    "$HOME/.local/bin"
    "$HOME/.config"
    "$HOME/.local/share"
    "$HOME/.local/state"
    "$HOME/.cache"
)
for dir in "${BASE_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        if [[ "${DRY_RUN:-false}" == true ]]; then
            print_dry "mkdir -p $dir"
        else
            mkdir -p "$dir"
        fi
    fi
done
success "Base directory layout verified"

# 4. Developer Fonts
info "Installing developer fonts to ~/Library/Fonts..."
FONT_DEST="$HOME/Library/Fonts"
mkdir -p "$FONT_DEST"
if [[ -d "$REPO/fonts" ]]; then
    typeset -i font_count=0
    for font_file in "$REPO/fonts"/**/*.(ttf|otf)(N); do
        font_name="${font_file:t}"
        if [[ ! -f "$FONT_DEST/$font_name" ]]; then
            if [[ "${DRY_RUN:-false}" == true ]]; then
                print_dry "cp $font_file $FONT_DEST/$font_name"
            else
                cp "$font_file" "$FONT_DEST/$font_name"
            fi
            (( font_count += 1 ))
        fi
    done
    if ((font_count > 0)); then
        success "Installed $font_count developer fonts to $FONT_DEST"
    else
        success "Developer fonts already present in $FONT_DEST"
    fi
fi

# 5. Canonical Zsh deployment
info "Deploying canonical Zsh configuration..."
typeset -a ZSH_ARGS
if [[ "${ASSURANT:-0}" -eq 1 ]]; then
    ZSH_ARGS=(--assurant)
else
    ZSH_ARGS=(--base)
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "$REPO/zsh/install.sh ${ZSH_ARGS[*]}"
else
    bash "$REPO/zsh/install.sh" "${ZSH_ARGS[@]}"
    success "Canonical Zsh config deployed into ~/.zsh"
fi

# 6. Sensible macOS Developer Defaults
info "Configuring macOS developer defaults..."
if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "Applying Finder and system developer preferences via defaults write"
else
    # Finder: show all extensions and hidden files
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder ShowStatusBar -bool true
    defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

    # Keyboard: fast repeat rate
    defaults write NSGlobalDomain KeyRepeat -int 2
    defaults write NSGlobalDomain InitialKeyRepeat -int 15

    # Expand save / print panels by default
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

    # Avoid creating .DS_Store on network / USB volumes
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

    # Restart Finder to apply view settings
    killall Finder >/dev/null 2>&1 || true
    success "macOS developer defaults applied"
fi

success "Stage 1: Base Environment & Core Shell complete"
