# Shared NVM PATH setup for shell startup and Mac maintenance.
# Resolve installed versions without loading nvm.sh or changing the default.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
typeset -U path PATH

_nvm_path_first() {
  local _node_bin="${NVM_BIN:-}" _target _i
  local -a _node_bins
  setopt local_options numeric_glob_sort

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

  case "$_target" in
    <->.<->.<->)
      _node_bins=("$NVM_DIR/versions/node/v$_target/bin"(N))
      ;;
    <->|<->.<->)
      _node_bins=("$NVM_DIR/versions/node"/v${_target}.*/bin(NOn))
      ;;
    node|stable|'*')
      _node_bins=("$NVM_DIR/versions/node"/v*/bin(NOn))
      ;;
    *)
      # Includes an explicit `system` default and unresolved aliases.
      return 0
      ;;
  esac

  for _node_bin in "${_node_bins[@]}"; do
    if [[ -x "$_node_bin/node" ]]; then
      path=("$_node_bin" $path)
      break
    fi
  done
  return 0
}

_nvm_path_first
