# Sourced by zsh after ~/.zshenv (which sets ZDOTDIR).
# Runs on every shell invocation, including non-interactive ones.
# Either ~/.zshenv sources us explicitly, or zsh sources us directly
# if ZDOTDIR is already set in the environment at startup.

# XDG Base Directories — centralizes config/cache/data/state locations.
# Defaults match the freedesktop spec; users can override by exporting before
# the shell starts (e.g. in /etc/environment).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Starship config lives alongside the zsh modules
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# Cargo (Rust) — must be available in non-interactive shells too
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Work-specific environment (sourced only when ZSH_WORK=1 in ~/.zshenv)
if [[ "${ZSH_WORK:-0}" == "1" ]]; then
  for _f in "$ZDOTDIR"/work/exports.zsh "$ZDOTDIR"/work/tools-extra.zsh; do
    [[ -f "$_f" ]] && source "$_f"
  done
  unset _f
fi
