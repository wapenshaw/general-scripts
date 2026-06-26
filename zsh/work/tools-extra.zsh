# SSH agent persistence for work — Assurant key.
# Only loaded when installed with --work.

if command -v keychain >/dev/null 2>&1; then
  eval "$(keychain --eval --quiet --agents ssh id_ed25519_assurant)"
fi
