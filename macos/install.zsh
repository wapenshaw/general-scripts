#!/usr/bin/env zsh
# macos/install.zsh — Stage-wise macOS Setup & Bootstrap Orchestrator
#
# Recreates this exact Mac setup from scratch across 4 clean stages:
#   Stage 1: Base Environment & Shell (Xcode CLI, Homebrew, Zsh, Fonts, macOS Defaults)
#   Stage 2: Developer Runtimes (Node/NVM, Python/uv, Rust/rustup, Bun, Go)
#   Stage 3: Applications & Packages (Brewfile CLI tools, Taps, GUI Casks, VS Code extensions)
#   Stage 4: App Configurations & Data (Git, SSH, Ghostty, LinearMouse, Karabiner, AI Configs)
#
# Usage:
#   ./macos/install.zsh                  # Run all stages with the default base profile
#   ./macos/install.zsh --stage=1        # Run Stage 1 only (env / zsh / fonts)
#   ./macos/install.zsh --stage=2        # Run Stage 2 only (runtimes: node, python, rust)
#   ./macos/install.zsh --stage=3        # Run Stage 3 only (apps / brew bundle)
#   ./macos/install.zsh --stage=4        # Run Stage 4 only (data / configs / ai)
#   ./macos/install.zsh --from=2         # Resume from Stage 2 through 4
#   ./macos/install.zsh --assurant       # Enable Assurant / work modules
#   ./macos/install.zsh --dry-run        # Print commands without modifying system
#
# Safe to re-run anytime. All stages are idempotent.
set -euo pipefail

SCRIPT_PATH="${0:A}"
REPO="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

source "$REPO/macos/lib/common.zsh"

if [[ "$(uname -s)" != "Darwin" ]]; then
    failure "This bootstrap installer is designed specifically for macOS."
    failure "On Linux use ./linux/install.sh; on Windows follow docs/FRESH-INSTALL.md."
    exit 2
fi

# Options & defaults: base/personal unless --assurant is passed.
export DRY_RUN=false
export ASSURANT=0
SELECTED_STAGE="all"
START_FROM=1

usage() {
    sed -n '3,18p' "$SCRIPT_PATH"
}

for arg in "$@"; do
    case "$arg" in
    --dry-run)
        export DRY_RUN=true
        ;;
    --assurant)
        export ASSURANT=1
        ;;
    --base)
        export ASSURANT=0
        ;;
    --all)
        SELECTED_STAGE="all"
        ;;
    --stage=*)
        SELECTED_STAGE="${arg#--stage=}"
        ;;
    --stage)
        print -u2 "Pass stage as --stage=1, --stage=env, etc."
        exit 2
        ;;
    --from=*)
        START_FROM="${arg#--from=}"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        failure "Unknown argument: $arg"
        usage
        exit 2
        ;;
    esac
done

# Normalize stage names
case "$SELECTED_STAGE" in
    1|env|environment)   SELECTED_STAGE=1 ;;
    2|runtime|runtimes)  SELECTED_STAGE=2 ;;
    3|app|apps|brew)     SELECTED_STAGE=3 ;;
    4|data|config|configs) SELECTED_STAGE=4 ;;
    all)                 SELECTED_STAGE="all" ;;
    *)
        failure "Invalid stage '$SELECTED_STAGE'. Valid options: 1 (env), 2 (runtimes), 3 (apps), 4 (data), all."
        exit 2
        ;;
esac

section "macOS Workstation Bootstrap"
info "Repo:     $REPO"
info "Machine:  $(scutil --get ComputerName 2>/dev/null || hostname)"
info "macOS:    $(sw_vers -productVersion) ($(uname -m))"
info "Profile:  $([[ "$ASSURANT" -eq 1 ]] && print 'Assurant / Work' || print 'Base / Personal (default)')"
info "Target:   $([[ "$SELECTED_STAGE" == "all" ]] && print "Stages $START_FROM through 4" || print "Stage $SELECTED_STAGE only")"

if [[ "$DRY_RUN" == true ]]; then
    warning "Dry-run mode enabled: commands will be printed but not executed."
fi

run_stage() {
    local num="$1"
    local script="$REPO/macos/stages/$2"
    if [[ ! -f "$script" ]]; then
        failure "Stage script not found: $script"
        exit 1
    fi
    zsh "$script"
}

# Execution planner
if [[ "$SELECTED_STAGE" == "1" || ("$SELECTED_STAGE" == "all" && "$START_FROM" -le 1) ]]; then
    run_stage 1 "01-environment.zsh"
fi

if [[ "$SELECTED_STAGE" == "2" || ("$SELECTED_STAGE" == "all" && "$START_FROM" -le 2) ]]; then
    run_stage 2 "02-runtimes.zsh"
fi

if [[ "$SELECTED_STAGE" == "3" || ("$SELECTED_STAGE" == "all" && "$START_FROM" -le 3) ]]; then
    run_stage 3 "03-apps.zsh"
fi

if [[ "$SELECTED_STAGE" == "4" || ("$SELECTED_STAGE" == "all" && "$START_FROM" -le 4) ]]; then
    run_stage 4 "04-data.zsh"
fi

section "Bootstrap Complete"
success "All selected macOS setup stages completed successfully!"
print "Next steps:"
print "  1. Reload your shell:     exec zsh -l"
print "  2. Authenticate GitHub:   gh auth login"
print "  3. Routine maintenance:   ./mac-update.zsh"
print
