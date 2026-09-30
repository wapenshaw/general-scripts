#!/usr/bin/env bash
# Render by default; pass --install to merge configs with private backups.
# Requires uv; forwards setup.py arguments unchanged.
set -euo pipefail
AI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v uv >/dev/null 2>&1; then
  printf 'Install uv first; it manages Python for this setup.\n' >&2
  exit 1
fi
exec uv run --no-project --python 3.14 "$AI_ROOT/setup.py" "$@"
