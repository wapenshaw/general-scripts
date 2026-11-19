# shellcheck shell=bash
# Keep the existing user history file as the canonical history store.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
# shellcheck disable=SC2034 # SAVEHIST is a zsh special parameter read by the shell, not a script variable.
SAVEHIST=50000

setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
