#!/usr/bin/env bash
# install.sh — symlink dotfiles into place
#
# Usage:
#   ./install.sh          # base install (no work-specific config)
#   ./install.sh --work   # also install work-specific modules
#
# Safe to re-run; existing files are backed up with a timestamp.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZDOTDIR="$HOME/.zsh"
TS="$(date +%Y%m%d%H%M%S)"

WORK=0
for arg in "$@"; do
  case "$arg" in
    --work) WORK=1 ;;
    -h|--help)
      sed -n '2,8p' "$0"
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
bold()   { printf '\033[1m%s\033[0m\n' "$1"; }

safe_link() {
  local src="$1" dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    mv "$dst" "${dst}.bak.${TS}"
    yellow "Backed up $(basename "$dst") → $(basename "$dst").bak.$TS"
  fi
  ln -sf "$src" "$dst"
  green "$(basename "$dst")"
}

bold "==> Creating directories"
mkdir -p "$ZDOTDIR"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"
green "~/.zsh/, XDG state/cache dirs"

echo ""
bold "==> Linking ~/.zshenv"
safe_link "$REPO/zshenv" "$HOME/.zshenv"

echo ""
bold "==> Linking ~/.zsh/ modules"
shopt -s dotglob
for src in "$REPO"/zsh/*; do
  [[ -e "$src" ]] || continue
  name="$(basename "$src")"
  [[ "$name" == "." || "$name" == ".." ]] && continue
  safe_link "$src" "$ZDOTDIR/$name"
done
shopt -u dotglob

# A regular ~/.zshrc would shadow the symlinked ~/.zsh/.zshrc.
# Back it up if it exists and isn't already a symlink to our ZDOTDIR.
if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$TS"
  yellow "Backed up ~/.zshrc → ~/.zshrc.bak.$TS (replaced by ~/.zsh/.zshrc via ZDOTDIR)"
fi

if [[ "$WORK" -eq 1 ]]; then
  echo ""
  bold "==> Linking ~/.zsh/work/ modules (--work)"
  mkdir -p "$ZDOTDIR/work"
  shopt -s dotglob
  for src in "$REPO"/work/*; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    case "$name" in
      .|..|az.env|az.env.example) continue ;;
    esac
    safe_link "$src" "$ZDOTDIR/work/$name"
  done
  shopt -u dotglob

  # Provide the az.env template if no real file exists yet
  if [[ ! -e "$ZDOTDIR/work/az.env" && -e "$REPO/work/az.env.example" ]]; then
    cp "$REPO/work/az.env.example" "$ZDOTDIR/work/az.env"
    yellow "Created ~/.zsh/work/az.env from template"
  fi
else
  echo ""
  yellow "Skipping work/ (run with --work to include Astra/Kubernetes/CA/SSH-agent config)"
fi

echo ""
bold "==> Done"
echo "  Open a new terminal or run:  exec zsh -l"
echo ""
echo "  First launch auto-installs missing plugins:"
echo "    zsh-autosuggestions"
echo "    zsh-history-substring-search"
echo "    fast-syntax-highlighting"
echo ""
echo "  Recommended tools to install:"
echo "    eza bat fd-find ripgrep fzf zoxide starship mise direnv keychain nvm lf nvim"

if [[ "$WORK" -eq 1 ]]; then
  echo ""
  bold "==> Action required: Azure IDs"
  echo "  Edit ~/.zsh/work/az.env and replace the placeholder values:"
  echo ""
  echo "      export AZ_TENANT_ID=\"<your-tenant-guid>\""
  echo "      export AZ_SUBSCRIPTION_ID=\"<your-subscription-guid>\""
  echo ""
  echo "  Find them with:"
  echo "      az account tenant list   --query '[].tenantId' -o tsv"
  echo "      az account list          --query '[].{name:name,id:id}' -o table"
  echo ""
  echo "  azfit / azdc will refuse to run until this file is filled in."
fi
