# Optional: start Herdr terminals in one fixed folder, whatever the app inherited.
# Off by default. Opt in by exporting HERDR_START_DIR (for example in a local,
# untracked file); nothing happens while it is unset.
# Herdr core sets HC_TERMINAL_ID in every terminal it spawns, so ordinary shells
# are untouched. HERDR_CD_DONE stops nested shells from jumping again.
if [[ -n "${HERDR_START_DIR:-}" && -n "${HC_TERMINAL_ID:-}" && -z "${HERDR_CD_DONE:-}" ]]; then
  export HERDR_CD_DONE=1
  [[ -d "$HERDR_START_DIR" ]] && cd "$HERDR_START_DIR"
fi
