# shellcheck shell=bash

# direnv — load/unload env vars per directory
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# zoxide — smart cd with frecency ranking (replaces plain cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# User-local environment loader (uv, etc.)
# shellcheck source=/dev/null
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
