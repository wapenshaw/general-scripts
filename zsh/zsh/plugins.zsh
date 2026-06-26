ZPLUGINDIR="$ZDOTDIR/plugins"

# Auto-clone if missing, then source the plugin
_zplugin_load() {
  local plugin_path="${ZPLUGINDIR}/${2}"
  if [[ ! -d "$plugin_path" ]]; then
    mkdir -p "$ZPLUGINDIR"
    echo "Installing ${2}..."
    git clone --depth=1 "https://github.com/${1}/${2}" "$plugin_path" \
      || { echo "ERROR: failed to install ${2}" >&2; return 1; }
  fi
  source "${plugin_path}/${2}.plugin.zsh"
}

# Update all plugins (run: zplugin-update)
zplugin-update() {
  local dir
  for dir in "${ZPLUGINDIR}"/*/; do
    echo "Updating ${dir:t}..."
    git -C "$dir" pull --ff-only
  done
}

_zplugin_load zsh-users zsh-autosuggestions
_zplugin_load zsh-users zsh-history-substring-search

# fast-syntax-highlighting must be loaded last (wraps ZLE widgets)
_zplugin_load zdharma-continuum fast-syntax-highlighting

# History substring search: arrows now search by what you've typed so far
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
