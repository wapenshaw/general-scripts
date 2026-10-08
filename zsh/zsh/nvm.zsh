export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# nvm-path.zsh already puts the selected Node first on PATH, so node, npm, npx
# and pnpm run directly. Load nvm.sh only when `nvm` itself is first used;
# --no-use keeps the active version instead of re-selecting the default.
nvm() {
  unset -f nvm
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh" --no-use
  nvm "$@"
}
