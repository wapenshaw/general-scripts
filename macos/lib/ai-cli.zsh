# Claude Code and Codex use their official standalone installers instead of
# Homebrew. Each puts a launcher in ~/.local/bin and updates itself in the
# background; `claude update` / `codex update` force an update on demand.
#
#   claude  ~/.local/bin/claude -> ~/.local/share/claude/versions/<version>
#   codex   ~/.local/bin/codex  -> ~/.codex/packages/standalone/current/bin/codex
#
# Callers provide command_exists, info, success and warning.

typeset -ga AI_CLI_TOOLS=(claude codex)
typeset -gA AI_CLI_CASKS=(claude claude-code codex codex)

# True when the tool is the standalone install in ~/.local/bin.
ai_cli_is_standalone() {
    local tool="$1"
    local link="$HOME/.local/bin/$tool"
    local target

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
