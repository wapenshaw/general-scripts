#!/usr/bin/env bash
# install.sh — copy this repo's opencode/ payload into the user's home dir.
#
# Target layout:
#   $HOME/.config/opencode/        — config files + skills/ + package.json
#   $HOME/.agents/skills/          — agent-skills/
#
# No symlinks. The repo's opencode/{config,skills,agent-skills,package.json}
# is copied into the XDG-style locations above.
#
# Usage:
#   ./install.sh          # default install
#   ./install.sh --uninstall
#
# Safe to re-run; identical files are skipped silently. Files that differ from
# the payload are backed up to <target>.bak-<yyyyMMdd-HHmmss> before overwrite.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$REPO"
CONFIG_TARGET="$HOME/.config/opencode"
SKILLS_TARGET="$HOME/.agents/skills"
TS="$(date +%Y%m%d-%H%M%S)"

UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

green()  { printf '\033[32m✓\033[0m %s\n' "$1"; }
yellow() { printf '\033[33m!\033[0m %s\n' "$1"; }
red()    { printf '\033[31m✗\033[0m %s\n' "$1"; }
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

# Managed-file manifest. These are the files this installer is allowed to
# create or remove. Anything else in the target dirs is left alone.
CONFIG_FILES=(
  "opencode.json"
  "oh-my-opencode-slim.json"
  "tui.json"
  "dcp.jsonc"
  "opencode-mem.jsonc"
  "quota-toast.json"
  "package.json"
  "themes/ayu-dark.json"
  "themes/lavi.json"
  "themes/poimandres-accessible.json"
  "themes/poimandres-turquoise-expanded.json"
  "themes/poimandres.json"
)
AGENT_SKILLS_DIRS=(
  "api-security-hardening"
  "authjs-skills"
  "context7-mcp"
  "dotnet-aspire"
  "find-skills"
  "frontend-design"
  "pinokio"
  "understand"
  "understand-chat"
  "understand-dashboard"
  "understand-diff"
  "understand-domain"
  "understand-explain"
  "understand-knowledge"
  "understand-onboard"
)
INTERNAL_SKILLS_DIRS=(
  "clonedeps"
  "codemap"
  "deepwork"
  "loop-engineering"
  "oh-my-opencode-slim"
  "reflect"
  "release-smoke-test"
  "simplify"
  "verification-planning"
  "worktrees"
)

if [[ ! -d "$SOURCE_DIR" ]]; then
  red "Source payload not found at $SOURCE_DIR"
  exit 1
fi

# ---------------------------------------------------------------------------
# diff-aware copy: identical files are skipped silently, differing files are
# backed up first.
# ---------------------------------------------------------------------------
copy_file() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    return 0
  fi
  if [[ -f "$dst" ]]; then
    cp -p "$dst" "$dst.bak-$TS"
    yellow "Backed up $dst -> $dst.bak-$TS"
  fi
  cp "$src" "$dst"
}

copy_tree() {
  local src_dir="$1" dst_dir="$2"
  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi
  mkdir -p "$dst_dir"
  # Use find + cp to mirror the directory contents (recursively), preserving
  # relative paths and skipping files whose content is identical.
  ( cd "$src_dir" && find . -type f ) | while IFS= read -r rel; do
    copy_file "$src_dir/$rel" "$dst_dir/$rel"
  done
}

# ---------------------------------------------------------------------------
# Uninstall: remove ONLY files this package manages.
# ---------------------------------------------------------------------------
do_uninstall() {
  bold "==> Uninstalling"
  local removed=0

  for f in "${CONFIG_FILES[@]}"; do
    local p="$CONFIG_TARGET/$f"
    if [[ -f "$p" ]]; then
      rm -f "$p"
      printf '  - removed %s\n' "$p"
      removed=$((removed + 1))
    fi
  done

  for d in "${INTERNAL_SKILLS_DIRS[@]}"; do
    local p="$CONFIG_TARGET/skills/$d"
    if [[ -d "$p" && ! -L "$p" ]]; then
      rm -rf "$p"
      printf '  - removed %s\n' "$p"
      removed=$((removed + 1))
    fi
  done

  for d in "${AGENT_SKILLS_DIRS[@]}"; do
    local p="$SKILLS_TARGET/$d"
    if [[ -d "$p" && ! -L "$p" ]]; then
      rm -rf "$p"
      printf '  - removed %s\n' "$p"
      removed=$((removed + 1))
    fi
  done

  green "Removed $removed managed file(s)/dir(s)"
  bold "==> Done"
  echo "  Unknown files in $CONFIG_TARGET and $SKILLS_TARGET were left untouched."
  echo "  Backups (if any) are still available at <original>.bak-$TS"
  exit 0
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  do_uninstall
fi

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
bold "==> Installing opencode config"

mkdir -p "$CONFIG_TARGET"
mkdir -p "$CONFIG_TARGET/skills"
mkdir -p "$SKILLS_TARGET"

# Top-level package.json + config/*.json|jsonc into $CONFIG_TARGET/
for f in package.json; do
  copy_file "$SOURCE_DIR/$f" "$CONFIG_TARGET/$f"
done
for f in "${CONFIG_FILES[@]}"; do
  [[ "$f" == "package.json" ]] && continue
  if [[ "$f" == themes/* ]]; then
    copy_file "$SOURCE_DIR/$f" "$CONFIG_TARGET/$f"
  else
    copy_file "$SOURCE_DIR/config/$f" "$CONFIG_TARGET/$f"
  fi
done

# Internal skills live under $CONFIG_TARGET/skills/
copy_tree "$SOURCE_DIR/skills" "$CONFIG_TARGET/skills"

# Agent skills live under $SKILLS_TARGET/ (the .agents location)
copy_tree "$SOURCE_DIR/agent-skills" "$SKILLS_TARGET"

green "Install complete"
echo ""
bold "==> Action required: env vars"
echo "  Export these in your shell profile before launching OpenCode:"
echo ""
echo "    export GITHUB_PERSONAL_ACCESS_TOKEN=\"<your-github-pat>\""
echo "    export CONTEXT7_API_KEY=\"ctx7sk-<your-context7-key>\""
echo ""
echo "  Google provider auth happens via:  opencode auth login"
echo "  (the projectId is baked into opencode.json and does not need to be set)"
echo ""
bold "==> Restart OpenCode to pick up the new config"
echo "  CLI: re-launch the opencode binary"
echo "  TUI: exit and restart the opencode TUI"
