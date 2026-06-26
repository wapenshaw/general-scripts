# Modular zsh config — each file owns one concern.
# Source order matters: exports before tools, fzf before bindings, plugins last.

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
source "$ZDOTDIR/prompt.zsh"    # starship after all plugins

# WSL helpers (az, k8s, open, rsb, etc.)
source "$ZDOTDIR/functions.zsh"

# Bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
