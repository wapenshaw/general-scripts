# WSL shell helpers

# =========================================================
# Git — stale remote-branch cleanup
# =========================================================

# Usage: rsb [PATH] [-r REMOTE] [-D] [-n]
rsb() {
  local target_path="."
  local remote="origin"
  local force=0
  local dry_run=0
  local found=0
  local child

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -D|--force)   force=1;   shift ;;
      -n|--dry-run) dry_run=1; shift ;;
      -r|--remote)  remote="${2:?missing remote name}"; shift 2 ;;
      -h|--help)
        cat <<'EOF'
Usage: rsb [PATH] [-r REMOTE] [-D] [-n]

  PATH          Repo path, or folder containing one-level child repos. Default: .
  -r, --remote  Remote name. Default: origin
  -D, --force   Use git branch -D instead of git branch -d
  -n, --dry-run Show stale branches without deleting
EOF
        return 0 ;;
      *) target_path="$1"; shift ;;
    esac
  done

  if [ ! -e "$target_path" ]; then
    printf 'Path does not exist: %s\n' "$target_path" >&2; return 1
  fi

  if git -C "$target_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    _rsb_clean_repo "$target_path" "$remote" "$force" "$dry_run"
    return $?
  fi

  for child in "$target_path"/*; do
    [ -d "$child" ] || continue
    if git -C "$child" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      found=1
      _rsb_clean_repo "$child" "$remote" "$force" "$dry_run"
    fi
  done

  [ "$found" -eq 0 ] && printf "No git repo found at '%s' or one level below it.\n" "$target_path" >&2 && return 1
}

_rsb_clean_repo() {
  local repo_path="$1" remote="$2" force="$3" dry_run="$4"
  local repo_root current_branch stale

  repo_root="$(git -C "$repo_path" rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'Not a git repo: %s\n' "$repo_path" >&2; return 1
  }

  printf '\nRepository: %s\n' "$repo_root"

  if ! git -C "$repo_root" remote get-url "$remote" >/dev/null 2>&1; then
    printf "Remote '%s' not found in %s\n" "$remote" "$repo_root" >&2; return 1
  fi

  git -C "$repo_root" fetch "$remote" --prune || {
    printf "Fetch failed in %s\n" "$repo_root" >&2; return 1
  }

  current_branch="$(git -C "$repo_root" branch --show-current 2>/dev/null)"

  stale="$(
    git -C "$repo_root" for-each-ref \
      --format='%(refname:short)|%(upstream:short)|%(upstream:track)' \
      refs/heads |
    awk -F'|' -v current="$current_branch" -v remote="$remote" '
      $1 == "" || $1 == current { next }
      $2 !~ "^" remote "/" { next }
      $3 ~ /\[gone\]/ { print $1 "|" $2 }
    '
  )"

  if [ -z "$stale" ]; then printf 'No stale branches found.\n'; return 0; fi

  printf 'Stale branches:\n'
  printf '%s\n' "$stale" | while IFS='|' read -r branch upstream; do
    printf '  %s  upstream: %s\n' "$branch" "$upstream"
  done

  printf '%s\n' "$stale" | while IFS='|' read -r branch _; do
    [ -n "$branch" ] || continue
    if [ "$dry_run" -eq 1 ]; then
      printf 'DRY RUN: would delete %s\n' "$branch"; continue
    fi
    if [ "$force" -eq 1 ]; then
      git -C "$repo_root" branch -D -- "$branch"
    else
      git -C "$repo_root" branch -d -- "$branch"
    fi
  done
}

# =========================================================
# WSL utilities
# =========================================================

open() {
  if command -v wslview >/dev/null 2>&1; then
    wslview "${1:-.}"
  else
    cmd.exe /c start "" "${1:-.}" >/dev/null 2>&1
  fi
}

explore() {
  explorer.exe "$(wslpath -w "${1:-.}")" >/dev/null 2>&1
}

clipcopy()  { clip.exe; }
clippaste() { powershell.exe -NoProfile -Command Get-Clipboard 2>/dev/null | tr -d '\r'; }

# =========================================================
# Navigation
# =========================================================

# up N — go up N directory levels; default 1
up() {
  local parents="${1:-1}"
  if [[ ! "$parents" -gt 0 ]]; then
    echo >&2 "usage: up [<num>]"
    return 1
  fi
  local dotdots=".."
  while (( --parents )); do dotdots+="/.."; done
  cd "$dotdots"
}

# =========================================================
# Utilities
# =========================================================

# sedi — cross-platform sed -i (GNU and BSD/macOS compatible)
sedi() { sed --version &>/dev/null && sed -i -- "$@" || sed -i "" "$@"; }
