autoload -Uz compinit

# Rebuild dump at most once per day; -C skips security check on cache hit
if [[ -n "$XDG_CACHE_HOME/zsh/zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
else
  compinit -C -d "$XDG_CACHE_HOME/zsh/zcompdump"
fi

# =========================================================
# Completion behavior (cherry-picked from zephyr/compstyle)
# =========================================================

# Cache completions (makes dpkg/apt/kubectl tolerable)
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"

# Arrow-key menu selection
zstyle ':completion:*:*:*:*:*' menu select

# Case-insensitive + partial-word + substring matching
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# Colorize completion menu using LS_COLORS
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-prompt '%S%M matches%s'

# Group matches and show descriptions
zstyle ':completion:*:matches'     group       'yes'
zstyle ':completion:*:options'     description 'yes'
zstyle ':completion:*:options'     auto-description '%d'
zstyle ':completion:*'             group-name  ''
zstyle ':completion:*'             verbose     yes

# Colored labels for each completion category
zstyle ':completion:*:corrections'  format ' %F{red}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format ' %F{magenta}-- %d --%f'
zstyle ':completion:*:messages'     format ' %F{green}-- %d --%f'
zstyle ':completion:*:warnings'     format ' %F{yellow}-- no matches --%f'
zstyle ':completion:*'              format ' %F{blue}-- %d --%f'

# Fuzzy approximate matching — tolerates typos
zstyle ':completion:*' completer _complete _match _approximate
zstyle ':completion:*:match:*'       original only
zstyle ':completion:*:approximate:*' max-errors 1 numeric

# Directory completion order
zstyle ':completion:*:*:cd:*' tag-order \
  local-directories directory-stack path-directories
zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
zstyle ':completion:*:-tilde-:*' group-order \
  'named-directories' 'path-directories' 'users' 'expand'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs ..

# History word completion
zstyle ':completion:*:history-words' stop            yes
zstyle ':completion:*:history-words' remove-all-dups yes
zstyle ':completion:*:history-words' list            false
zstyle ':completion:*:history-words' menu            yes

# Kill — show process list with colors
zstyle ':completion:*:*:*:*:processes' \
  command 'ps -u $LOGNAME -o pid,user,command -w'
zstyle ':completion:*:*:kill:*:processes' \
  list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;36=0=01'
zstyle ':completion:*:*:kill:*' menu           yes select
zstyle ':completion:*:*:kill:*' force-list     always
zstyle ':completion:*:*:kill:*' insert-ids     single

# Man pages — separate by section
zstyle ':completion:*:manuals'        separate-sections true
zstyle ':completion:*:manuals.(^1*)' insert-sections   true
zstyle ':completion:*:man:*'          menu              yes select

# SSH/SCP/RSYNC — read hosts from known_hosts + ssh config
zstyle ':completion:*:(ssh|scp|rsync):*' tag-order \
  'hosts:-host:host hosts:-domain:domain hosts:-ipaddr:ip\ address *'
zstyle -e ':completion:*:hosts' hosts 'reply=(
  ${=${=${=${${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts(|2)(N) 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
  ${=${(f)"$(cat /etc/hosts(|)(N) 2>/dev/null)"}%%\#*}
  ${=${${${${(@M)${(f)"$(cat ~/.ssh/config 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
)'

# Don't complete internal functions or uninteresting users
zstyle ':completion:*:functions'       ignored-patterns '(_*|pre(cmd|exec))'
zstyle ':completion:*:*:*:users'       ignored-patterns \
  adm amanda apache avahi bin cacti canna clamav daemon dbus distcache \
  dovecot fax ftp games gdm gopher hacluster haldaemon halt hsqldb ident \
  junkbust ldap lp mail mailman mailnull mldonkey mysql nagios named \
  netdump news nfsnobody nobody nscd ntp nut nx openvpn operator pcap \
  postfix postgres privoxy pulse pvm quagga radvd rpc rpcuser rpm \
  shutdown squid sshd sync uucp vcsa xfs '_*'
