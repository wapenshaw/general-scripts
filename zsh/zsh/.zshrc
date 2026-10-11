# Modular zsh config — each file owns one concern.
# Source order matters: exports before tools, fzf before bindings, plugins last.
# Assurant modules (aliases, functions) are only sourced when ZSH_ASSURANT=1.

source "$ZDOTDIR/history.zsh"
source "$ZDOTDIR/exports.zsh"
source "$ZDOTDIR/completion.zsh"
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/tools.zsh"
source "$ZDOTDIR/nvm.zsh"
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/functions.zsh"
if [[ "${ZSH_ASSURANT:-0}" == "1" && -f "$ZDOTDIR/uv.zsh" ]]; then
  source "$ZDOTDIR/uv.zsh"
fi
source "$ZDOTDIR/bindings.zsh"
source "$ZDOTDIR/plugins.zsh"   # fast-syntax-highlighting must stay last plugin

# Assurant aliases and functions. Exports/tools-extra are in .zshenv
# so non-interactive shells can see them too.
if [[ "${ZSH_ASSURANT:-0}" == "1" ]]; then
  for _f in "$ZDOTDIR"/work/aliases.zsh "$ZDOTDIR"/work/functions.zsh; do
    [[ -f "$_f" ]] && source "$_f"
  done
  unset _f
fi

# Grok CLI
if [[ -d "$HOME/.grok" ]]; then
  export PATH="$HOME/.grok/bin:$PATH"
  fpath=(~/.grok/completions/zsh $fpath)
fi

# oh-my-opencode-slim background subagents
export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true

source "$ZDOTDIR/prompt.zsh"    # starship after all plugins

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# Apply NVM priority after exports and all other interactive PATH setup.
if (( $+functions[_nvm_path_first] )); then
  _nvm_path_first
fi
