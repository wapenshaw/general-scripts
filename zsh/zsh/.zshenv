# Sourced by zsh after ~/.zshenv (which sets ZDOTDIR).
# Runs on every shell invocation, including non-interactive ones.
# Either ~/.zshenv sources us explicitly, or zsh sources us directly
# if ZDOTDIR is already set in the environment at startup.

export ZDOTDIR="$HOME/.zsh"
export skip_global_compinit=1

# XDG Base Directories — centralizes config/cache/data/state locations.
# Defaults match the freedesktop spec; users can override by exporting before
# the shell starts (e.g. in /etc/environment).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Starship config lives alongside the zsh modules
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# Node (nvm) — available in non-interactive shells and background processes.
# 1. If an active session already set NVM_BIN (via `nvm use`), preserve that active version.
# 2. Otherwise, resolve the NVM default alias (following any alias chains e.g. lts/*)
#    and match against installed versions without spawning slow nvm.sh subshells.
if [[ -n "${NVM_BIN:-}" && -d "$NVM_BIN" ]]; then
  case ":${PATH}:" in
    *:"$NVM_BIN":*) ;;
    *) export PATH="$NVM_BIN:$PATH" ;;
  esac
elif [[ -d "$HOME/.nvm/versions/node" ]]; then
  _target=""
  if [[ -f "$HOME/.nvm/alias/default" ]]; then
    _target="$(<"$HOME/.nvm/alias/default")"
    for _i in {1..5}; do
      if [[ -f "$HOME/.nvm/alias/$_target" ]]; then
        _target="$(<"$HOME/.nvm/alias/$_target")"
      else
        break
      fi
    done
    unset _i
  fi
  _target="${_target#v}"
  _default_node=""
  if [[ -n "$_target" && "$_target" != "*" ]]; then
    _default_node="$(print -l "$HOME/.nvm/versions/node"/v${_target}*/bin(NOn) 2>/dev/null | head -n 1)"
  fi
  if [[ -z "$_default_node" ]]; then
    _default_node="$(print -l "$HOME/.nvm/versions/node"/v*/bin(NOn) 2>/dev/null | head -n 1)"
  fi
  if [[ -n "$_default_node" && -d "$_default_node" ]]; then
    case ":${PATH}:" in
      *:"$_default_node":*) ;;
      *) export PATH="$_default_node:$PATH" ;;
    esac
  fi
  unset _target _default_node
fi

# Cargo (Rust) — available in non-interactive shells, but only when rustup's
# cargo is actually installed. rustup self uninstall removes ~/.cargo/bin/cargo;
# leftover env files must not keep a dead directory on PATH.
if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
  if [[ -f "$HOME/.cargo/env" ]]; then
    . "$HOME/.cargo/env"
  else
    case ":${PATH}:" in
      *:"$HOME/.cargo/bin":*) ;;
      *) export PATH="$HOME/.cargo/bin:$PATH" ;;
    esac
  fi
fi

# Assurant environment (sourced only when install.sh --assurant set ZSH_ASSURANT=1).
if [[ "${ZSH_ASSURANT:-0}" == "1" ]]; then
  for _f in "$ZDOTDIR"/work/exports.zsh "$ZDOTDIR"/work/tools-extra.zsh; do
    [[ -f "$_f" ]] && source "$_f"
  done
  unset _f
fi
