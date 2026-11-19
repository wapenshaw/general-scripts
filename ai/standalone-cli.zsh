#!/usr/bin/env zsh

# Claude Code, Codex and omp (oh-my-pi) use their official standalone
# installers instead of Homebrew (macOS casks or Linuxbrew). Each puts its
# command in ~/.local/bin and can update itself; `<tool> update` forces an
# update on demand. Sourced by mac-update.zsh and linux-update.zsh (whose
# --bootstrap is the macOS bootstrap path); linux/install.sh mirrors
# ai_cli_install in bash.
#
#   claude  ~/.local/bin/claude -> ~/.local/share/claude/versions/<version>
#   codex   ~/.local/bin/codex  -> ~/.codex/packages/standalone/current/bin/codex
#   omp     ~/.local/bin/omp    (a plain binary, replaced in place; releases ship
#                                almost daily and Homebrew has no formula)
#
# Callers provide command_exists, info, success and warning; ai_cli_maintain
# also needs run_step and add_warning from the update scripts.

typeset -ga AI_CLI_TOOLS=(claude codex omp)
typeset -gA AI_CLI_CASKS=([claude]=claude-code [codex]=codex)
# Installed on every run when missing, not only with --bootstrap.
typeset -ga AI_CLI_ALWAYS_INSTALL=(omp)

# True when the tool is the standalone install in ~/.local/bin.
ai_cli_is_standalone() {
    local tool="$1"
    local link="$HOME/.local/bin/$tool"
    local target

    # omp's installer moves the binary into place instead of linking it.
    if [[ "$tool" == omp ]]; then
        [[ -f "$link" && -x "$link" && ! -L "$link" ]]
        return
    fi

    [[ -L "$link" ]] || return 1
    target="$(readlink "$link")" || return 1

    case "$tool" in
    claude) [[ "$target" == "$HOME/.local/share/claude/versions/"* ]] ;;
    codex) [[ "$target" == "${CODEX_HOME:-$HOME/.codex}/packages/standalone/"* ]] ;;
    *) return 1 ;;
    esac
}

# Runs the official installer for one tool.
ai_cli_install() {
    case "$1" in
    claude)
        curl -fsSL https://claude.ai/install.sh | bash
        ;;
    codex)
        # The installer edits shell profiles when it finds another codex on
        # PATH, so hide Homebrew/npm copies; ~/.local/bin is already on PATH.
        curl -fsSL https://chatgpt.com/codex/install.sh |
            PATH="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
                CODEX_NON_INTERACTIVE=1 sh
        ;;
    omp)
        # Prebuilt binary, SHA-256 checked and smoke-tested by the installer.
        # It only prints a PATH hint; it never edits shell profiles.
        curl -fsSL https://omp.sh/install.sh |
            PI_INSTALL_DIR="$HOME/.local/bin" sh -s -- --binary
        ;;
    *)
        return 2
        ;;
    esac
}

# Prints the Homebrew cask name when the tool is still installed as a cask.
ai_cli_brew_cask() {
    local cask="${AI_CLI_CASKS[$1]:-}"

    [[ -n "$cask" ]] || return 1
    command_exists brew || return 1
    brew list --cask "$cask" >/dev/null 2>&1 || return 1
    print -r -- "$cask"
}

# Migrates leftover Homebrew casks to the standalone installs, then updates
# them. A missing tool is installed when the first argument is true or the
# tool is in AI_CLI_ALWAYS_INSTALL.
ai_cli_maintain() {
    local bootstrap="${1:-false}"
    local tool cask

    for tool in "${AI_CLI_TOOLS[@]}"; do
        cask="$(ai_cli_brew_cask "$tool" || true)"

        if ! ai_cli_is_standalone "$tool"; then
            if [[ -n "$cask" || "$bootstrap" == true ]] ||
                (( ${AI_CLI_ALWAYS_INSTALL[(Ie)$tool]} )); then
                run_step \
                    "Install $tool with its standalone installer" \
                    ai_cli_install "$tool"
            else
                warning "$tool is not installed with its standalone installer"
                print "Install it with --bootstrap"
                add_warning "$tool standalone install missing"
                continue
            fi
        fi

        # The cask goes only once the standalone install is in place.
        if [[ -n "$cask" ]]; then
            if [[ "${DRY_RUN:-false}" == true ]] || ai_cli_is_standalone "$tool"; then
                run_step \
                    "Remove Homebrew cask $cask (standalone install updates itself)" \
                    brew uninstall --cask --force "$cask"
            else
                warning "Keeping Homebrew $cask because the standalone install failed"
                add_warning "$tool is still installed through Homebrew"
            fi
        fi

        ai_cli_is_standalone "$tool" || continue

        run_step "Update $tool" "$HOME/.local/bin/$tool" update
        hash -r

        if [[ "$(command -v "$tool")" == "$HOME/.local/bin/$tool" ]]; then
            success "$tool: $("$tool" --version 2>&1 | head -n 1)"
        else
            warning "$tool resolves to $(command -v "$tool")"
            warning "Expected the standalone launcher $HOME/.local/bin/$tool"
            add_warning "$tool executable location"
        fi
    done
}
