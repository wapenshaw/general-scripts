#!/usr/bin/env bash
set -euo pipefail

command="$(jq -r '.tool_input.command // ""')"
flat="$(printf '%s' "$command" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Destructive Git operations.
if printf '%s\n' "$flat" | grep -Eqi \
  'git .*reset .*--hard|git .*clean .*-[^ ]*f|git .*push .*(--force|--force-with-lease|-f([[:space:]]|$))'
then
  deny "Blocked destructive Git operation. Run it manually if intentional."
fi

# Infrastructure destruction.
if printf '%s\n' "$flat" | grep -Eqi \
  'terraform[[:space:]]+destroy([[:space:]]|$)|helm[[:space:]]+uninstall([[:space:]]|$)|az[[:space:]].*[[:space:]]delete([[:space:]]|$)'
then
  deny "Blocked destructive infrastructure operation. Run it manually if intentional."
fi

# High-impact Kubernetes deletion.
if printf '%s\n' "$flat" | grep -Eqi \
  'kubectl .*delete[[:space:]]+(namespace|ns|persistentvolume|pv|persistentvolumeclaim|pvc)([[:space:]]|$)'
then
  deny "Blocked destructive Kubernetes deletion. Run it manually if intentional."
fi

# Catastrophic filesystem removal, while still allowing things such as
# rm -rf build/ or rm -rf .pytest_cache/.
if printf '%s\n' "$flat" | grep -Eqi \
  '(^|[;&|][[:space:]]*)(/bin/)?rm[[:space:]]+-(rf|fr|[^ ]*r[^ ]*f|[^ ]*f[^ ]*r)[[:space:]]+(/|~|\$HOME|\.|\.\.)([[:space:];|&]|$)'
then
  deny "Blocked catastrophic filesystem deletion."
fi

exit 0