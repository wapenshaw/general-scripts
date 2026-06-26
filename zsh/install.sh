#!/usr/bin/env bash
# install.sh — symlink dotfiles into place
# Run once on a fresh machine. Safe to re-run; existing files are backed up.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZDOTDIR="$HOME/.zsh"
TS="$(date +%Y%m%d%H%M%S)"

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
mkdir -p "$ZDOTDIR/plugins"
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
echo "    eza bat fd-find ripgrep fzf zoxide starship mise direnv keychain nvim lf"
