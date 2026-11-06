#!/bin/sh
# User-level install of repo-knowledge for every agent CLI present on this machine.
# Idempotent; safe to re-run after pulling changes.
#   1. CLI:   uv tool install --editable (edits here take effect without reinstalling)
#   2. Skill: ~/.agents/skills/repo-knowledge -> this package's SKILL.md folder
#             (Codex, Copilot, OpenCode); ~/.claude/skills/repo-knowledge -> ../../.agents/skills/...
#   3. MCP:   "repo-knowledge serve" registered at user scope with each installed client
#             (claude, codex, copilot). Missing clients are skipped.
# Each project opts in with a knowledge.toml at its root (`repo-knowledge example-config`).
set -eu

DIR=$(cd "$(dirname "$0")" && pwd)
NAME=repo-knowledge
SKILL_SRC="$DIR/src/repo_knowledge/skills/$NAME"
BACKUP="$HOME/.local/state/ai-config-backups/$NAME-$(date +%Y%m%d-%H%M%S)"

backup() { # back up a config file privately before a client CLI edits it
    if [ -f "$1" ]; then mkdir -p "$BACKUP" && cp -p "$1" "$BACKUP/$(echo "$1" | tr / _)"; fi
}

echo "== CLI"
uv tool install --editable --force "$DIR" >/dev/null 2>&1
BIN="$(cd "$(uv tool dir --bin)" && pwd -P)/$NAME"
"$BIN" --help >/dev/null && echo "installed $BIN"

echo "== Skill"
mkdir -p "$HOME/.agents/skills"
ln -sfn "$SKILL_SRC" "$HOME/.agents/skills/$NAME" && echo "linked ~/.agents/skills/$NAME"
if [ -d "$HOME/.claude" ]; then
    mkdir -p "$HOME/.claude/skills"
    ln -sfn "../../.agents/skills/$NAME" "$HOME/.claude/skills/$NAME" && echo "linked ~/.claude/skills/$NAME"
fi

echo "== MCP"
if command -v claude >/dev/null 2>&1; then
    backup "$HOME/.claude.json"   # re-register so a moved binary path is picked up
    claude mcp remove --scope user "$NAME" >/dev/null 2>&1 || true
    claude mcp add --scope user "$NAME" -- "$BIN" serve >/dev/null && echo "claude: registered (user scope)"
else echo "claude: not installed, skipped"; fi
if command -v codex >/dev/null 2>&1; then
    backup "$HOME/.codex/config.toml"
    codex mcp remove "$NAME" >/dev/null 2>&1 || true
    codex mcp add "$NAME" -- "$BIN" serve >/dev/null && echo "codex: registered"
else echo "codex: not installed, skipped"; fi
if command -v copilot >/dev/null 2>&1; then
    backup "$HOME/.copilot/mcp-config.json"
    copilot mcp add "$NAME" -- "$BIN" serve >/dev/null 2>&1 && echo "copilot: registered" \
        || echo "copilot: add failed or already present; check ~/.copilot/mcp-config.json"
else echo "copilot: not installed, skipped"; fi
[ -d "$BACKUP" ] && echo "backups: $BACKUP"
echo "Done. Add knowledge.toml to a project root to enable it there: $NAME example-config > knowledge.toml"
