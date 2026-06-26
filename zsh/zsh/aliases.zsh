# Navigation
alias -- -='cd -'
alias cda='cd "$ASTRA_HOME"'
alias astra='cd "$ASTRA_HOME/Common-Automation"'

# Dirstack — cd to numbered history positions (auto_pushd makes every cd push)
alias dirh='dirs -v'   # show numbered dirstack
alias 1='cd -1'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'

# Global dot-dot aliases — ..2 = ../..  ..3 = ../../..  etc.
alias -g ..2='../..'
alias -g ..3='../../..'
alias -g ..4='../../../..'
alias -g ..5='../../../../..'

# lf — follows the directory you navigated to when you quit
lf() {
  local tmp
  tmp=$(mktemp)
  command lf -last-dir-path="$tmp" "$@"
  if [ -f "$tmp" ]; then
    local dir
    dir=$(cat "$tmp")
    rm -f "$tmp"
    [ -d "$dir" ] && [ "$dir" != "$(pwd)" ] && cd "$dir"
  fi
}

# Shell
alias cls='clear'
alias reload='exec zsh -l'
alias cheat='bat ~/.zsh/cheatsheet.md'
alias vim='nvim'
alias colormap='for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+"\n"}; done'

# Better help for shell builtins (man zshoptions, etc.)
(( $+aliases[run-help] )) && unalias run-help
autoload -Uz run-help
alias help='run-help'

# Python — ensure unversioned commands exist if only python3/pip3 are installed
(( $+commands[python3] )) && ! (( $+commands[python] )) && alias python='python3'
(( $+commands[pip3]    )) && ! (( $+commands[pip]    )) && alias pip='pip3'

# System maintenance
alias sysup='sudo apt update -y && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt clean -y && sudo apt autoclean -y'

# ls / eza (icons + git status)
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons'
compdef eza=ls

# Better cat and paging
alias cat='bat'

# Core utils
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# Safety prompts
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Git
alias gb='git branch --show-current'
alias gco='git checkout'
alias gl='git log --oneline --decorate --graph -20'
alias glog='PAGER="less -F -X" git log'
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias gs='git status --short'
alias gst='git status'

# Kubernetes / Infra
alias k='kubectl'
alias h='helm'
alias tf='terraform'
alias kctx='kubectl config current-context'

# Docker
alias d='docker'
alias dc='docker compose'
