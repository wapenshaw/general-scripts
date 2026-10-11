#!/usr/bin/env zsh
# macos/lib/common.zsh — shared helpers for macOS bootstrap stages
autoload -U colors && colors

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

info() {
    print -P "%F{cyan}==>%f $*"
}

success() {
    print -P "%F{green}✓%f $*"
}

warning() {
    print -P "%F{yellow}Warning:%f $*"
}

failure() {
    print -P "%F{red}Error:%f $*"
}

section() {
    print
    print -P "%B%F{blue}========================================%f%b"
    print -P "%B%F{blue}  $*%f%b"
    print -P "%B%F{blue}========================================%f%b"
    print
}

print_dry() {
    print -P "  %F{yellow}[dry-run]%f $*"
}

run_cmd() {
    local desc="$1"
    shift
    info "$desc"
    if [[ "${DRY_RUN:-false}" == true ]]; then
        print_dry "$*"
        return 0
    fi
    "$@"
}
