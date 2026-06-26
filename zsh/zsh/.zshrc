# Modular zsh config — each file owns one concern.
# Source order matters: exports before tools, fzf before bindings, plugins last.
# Work-specific modules (work/exports.zsh, work/aliases.zsh, work/functions.zsh,
# work/tools-extra.zsh) are only present when installed with --work.

source "$ZDOTDIR/history.zsh"
source "$ZDOTDIR/exports.zsh"
source "$ZDOTDIR/completion.zsh"
source "$ZDOTDIR/fzf.zsh"
source "$ZDOTDIR/tools.zsh"
source "$ZDOTDIR/nvm.zsh"
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/uv.zsh"
source "$ZDOTDIR/bindings.zsh"
source "$ZDOTDIR/plugins.zsh"   # fast-syntax-highlighting must stay last plugin

# Work-specific (no-ops if work/ is absent)
for _f in "$ZDOTDIR"/work/exports.zsh "$ZDOTDIR"/work/tools-extra.zsh "$ZDOTDIR"/work/aliases.zsh "$ZDOTDIR"/work/functions.zsh; do
  [[ -f "$_f" ]] && source "$_f"
done
unset _f

source "$ZDOTDIR/prompt.zsh"    # starship after all plugins

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
