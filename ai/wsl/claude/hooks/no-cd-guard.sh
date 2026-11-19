#!/usr/bin/env bash
# PreToolUse: Bash — block bare `cd` that changes the persistent CWD.
# The working directory persists across Claude Code Bash calls; changing it
# breaks session tracking, context compaction, and $CLAUDE_PROJECT_DIR references.
# Exception: cd inside a subshell (cd /path && ...) does NOT change the parent CWD.

set -o pipefail

payload=""
if [[ ! -t 0 ]]; then
  payload="$(cat 2>/dev/null || true)"
fi

cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[[ -z "$cmd" ]] && exit 0

# Remove subshell groups — cd inside (...) doesn't affect the persistent CWD
stripped="$(printf '%s' "$cmd" | sed 's/([^)]*)/SUBSHELL/g')"

# Match bare cd: at start of command, after &&, after ;, or after a newline
if printf '%s' "$stripped" | grep -qE '(^|&&|;|\n)[[:space:]]*cd[[:space:]]'; then
  printf '%s\n' "BLOCKED (no-cd-guard): Do not use 'cd' to change directories." >&2
  printf '%s\n' "CWD persists across Bash calls — changing it breaks session tracking," >&2
  printf '%s\n' "context compaction, and \$CLAUDE_PROJECT_DIR hook references." >&2
  printf '%s\n' "Use absolute paths instead, or wrap in a subshell: (cd /path && command)" >&2
  exit 2
fi

exit 0
