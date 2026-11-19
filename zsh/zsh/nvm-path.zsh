# Shared NVM PATH setup for shell startup and Mac maintenance.
# Resolve installed versions without loading nvm.sh or changing the default.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
typeset -U path PATH

_nvm_path_first() {
  local _node_bin="${NVM_BIN:-}" _target _i
  local -a _node_bins
  setopt local_options null_glob numeric_glob_sort

  if [[ -n "$_node_bin" && -x "$_node_bin/node" ]]; then
    path=("$_node_bin" $path)
    return 0
  fi
  [[ -d "$NVM_DIR/versions/node" ]] || return 0

  _target=node
  if [[ -f "$NVM_DIR/alias/default" ]]; then
    _target=default
    # -f, not -r: an empty alias would otherwise resolve to the alias directory.
    for _i in {1..10}; do
      [[ -n "$_target" && -f "$NVM_DIR/alias/$_target" ]] || break
      _target="$(<"$NVM_DIR/alias/$_target")"
    done
    # An unresolved chain after ten steps is cyclic or too long.
    [[ -n "$_target" && -f "$NVM_DIR/alias/$_target" ]] && return 0
  fi
  _target="${_target#v}"

  if [[ "$_target" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    _node_bins=("$NVM_DIR/versions/node/v$_target/bin")
  elif [[ "$_target" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    _node_bins=($NVM_DIR/versions/node/v${_target}.*/bin)
  elif [[ "$_target" == node || "$_target" == stable || "$_target" == '*' ]]; then
    _node_bins=($NVM_DIR/versions/node/v*/bin)
  else
    # Includes an explicit `system` default and unresolved aliases.
    return 0
  fi

  # Newest version first: glob results are sorted numerically ascending.
  for (( _i = ${#_node_bins[@]}; _i >= 1; _i-- )); do
    _node_bin="${_node_bins[_i]}"
    if [[ -x "$_node_bin/node" ]]; then
      path=("$_node_bin" $path)
      break
    fi
  done
  return 0
}

_nvm_path_first
