#!/usr/bin/env zsh
# macos/stages/03-apps.zsh — Stage 3: Applications & Package Manager
#
# Installs all curated CLI packages, taps, GUI applications (casks), and
# extensions defined in macos/Brewfile.
set -euo pipefail

STAGE_DIR="${0:A:h}"
REPO="${STAGE_DIR:h:h}"
BREWFILE="$REPO/macos/Brewfile"

source "$REPO/macos/lib/common.zsh"

section "Stage 3: Applications & Package Manager"

if ! command_exists brew; then
    failure "Homebrew is missing. Please run Stage 1 first."
    exit 1
fi

if [[ ! -f "$BREWFILE" ]]; then
    failure "Brewfile not found at $BREWFILE"
    exit 1
fi

info "Updating Homebrew metadata..."
if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "brew update"
else
    brew update
fi

info "Installing packages from $BREWFILE..."
if [[ "${DRY_RUN:-false}" == true ]]; then
    print_dry "brew bundle check --file=$BREWFILE"
    print_dry "brew bundle --file=$BREWFILE"
else
    if brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
        success "All packages in Brewfile are already installed"
    else
        info "Applying Brewfile bundle (installing missing formulas, casks, and taps)..."
        brew bundle --file="$BREWFILE" || {
            warning "Some Brewfile packages could not be installed immediately."
            warning "Review output above for any casks requiring manual password/permissions."
        }
        success "Brewfile bundle processing complete"
    fi
fi

success "Stage 3: Applications & Package Manager complete"
