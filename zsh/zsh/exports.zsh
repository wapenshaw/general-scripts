# Deduplicate PATH entries automatically
typeset -U path PATH

# Local user binaries first
path=("$HOME/.local/bin" $path)

# Bun and tfenv
export BUN_INSTALL="$HOME/.bun"
path=("$BUN_INSTALL/bin" "$HOME/.tfenv/bin" $path)

# Remove Windows Node/NVM pollution from WSL PATH
path=(${path:#/mnt/c/nvm4w/*})

# Workspace
export ASTRA_HOME="$HOME/astra"

# Kubernetes
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Corporate CA compatibility (Assurant)
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
export CURL_CA_BUNDLE="$SSL_CERT_FILE"

# Node.js — NODE_USE_SYSTEM_CA covers CA trust; ipv4first avoids WSL DNS hangs
export NODE_USE_SYSTEM_CA=1
export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
export NODE_OPTIONS="--dns-result-order=ipv4first"

# npm
export npm_config_cafile="$SSL_CERT_FILE"
export npm_config_strict_ssl=true

# Editor
export EDITOR="nvim"
export VISUAL="nvim"

# uv
export UV_LINK_MODE=clone
export UV_PYTHON=3.14
export UV_PYTHON_PREFERENCE=managed
export UV_CACHE_DIR="$HOME/.cache/uv"

# GPG (interactive shells only — tty is defined here)
export GPG_TTY=$(tty)

# Better man pages via bat
export MANPAGER="bat -l man -p"

# Shell options
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt COMPLETE_IN_WORD
setopt NO_BEEP
setopt NUMERIC_GLOB_SORT
setopt NO_flow_control    # frees Ctrl+Q and Ctrl+S for keybindings
setopt auto_pushd         # cd pushes old dir onto dirstack automatically
setopt pushd_minus        # swap +/- for dirstack nav (cd -1, cd +1)
setopt pushd_silent       # no output from pushd/popd
setopt extended_glob      # enable #, ~, ^ in glob patterns
setopt glob_dots          # dotfiles match globs without needing .*
setopt NO_clobber         # > won't overwrite existing files; use >| to force
setopt NO_rm_star_silent  # prompt for confirmation before rm *
setopt multios            # allow writing to multiple descriptors simultaneously

# WORDCHARS — chars treated as part of a word for Ctrl+W / Alt+D
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'

# LS_COLORS — used by completion menu and dircolors-aware tools
if (( $+commands[dircolors] )); then
  source <(dircolors --sh)
fi
export LS_COLORS="${LS_COLORS:-di=34:ln=35:so=32:pi=33:ex=31:bd=1;36:cd=1;33:su=30;41:sg=30;46:tw=30;42:ow=30;43}"
