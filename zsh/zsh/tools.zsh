# mise — tool/version manager; must activate before prompt so shims resolve
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# SSH agent persistence (avoids repeated passphrase prompts)
if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --agents ssh id_ed25519_assurant)"
fi

# direnv — load/unload env vars per directory
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# zoxide — smart cd with frecency ranking (replaces plain cd)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# User-local environment loader (uv, mise shims, etc.)
[ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
