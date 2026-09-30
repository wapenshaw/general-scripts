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

# mise owns Node and other non-Python runtimes. Initialize its environment
# here so mise-managed tools also work in non-interactive shells; tools.zsh
# adds the interactive directory hooks later.
_mise_bin=''
if [[ -x /opt/homebrew/bin/mise ]]; then
  _mise_bin=/opt/homebrew/bin/mise
elif command -v mise >/dev/null 2>&1; then
  _mise_bin="$(command -v mise)"
fi
if [[ -n "$_mise_bin" ]]; then
  eval "$("$_mise_bin" env -s zsh 2>/dev/null)"
fi
unset _mise_bin

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
