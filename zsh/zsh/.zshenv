# Sourced by zsh after ~/.zshenv (which sets ZDOTDIR).
# Runs on every shell invocation, including non-interactive ones.
# Either ~/.zshenv sources us explicitly, or zsh sources us directly
# if ZDOTDIR is already set in the environment at startup.

export ZDOTDIR="$HOME/.zsh"
export skip_global_compinit=1
typeset -U path PATH

# Homebrew — must be here (read by EVERY zsh, including non-interactive ones),
# not only in .zprofile/.zshrc. A Herdr server started by a `herdr --remote`
# client over SSH runs `zsh -c` and would otherwise have no Homebrew on PATH, so
# plugins fail with "fzf is not installed". Guarded: no-op if brew is absent.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
done
unset _brew

# XDG Base Directories — centralizes config/cache/data/state locations.
# Defaults match the freedesktop spec; users can override by exporting before
# the shell starts (e.g. in /etc/environment).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Starship config lives alongside the zsh modules
export STARSHIP_CONFIG="$ZDOTDIR/starship.toml"

# User binaries and Cargo (Rust) — available in non-interactive shells.
# Re-apply after Homebrew so ~/.local/bin and rustup win over Homebrew binaries.
# rustup self uninstall removes ~/.cargo/bin/cargo; leftover env files must not keep a dead dir.
if [[ -x "$HOME/.cargo/bin/cargo" ]]; then
  path=("$HOME/.local/bin" "$HOME/.cargo/bin" $path)
else
  path=("$HOME/.local/bin" $path)
fi

# Assurant environment (sourced only when install.sh --assurant set ZSH_ASSURANT=1).
if [[ "${ZSH_ASSURANT:-0}" == "1" ]]; then
  for _f in "$ZDOTDIR"/work/exports.zsh "$ZDOTDIR"/work/tools-extra.zsh; do
    [[ -f "$_f" ]] && source "$_f"
  done
  unset _f
fi

# Run last so Homebrew, user-local binaries, and work exports cannot shadow NVM.
[[ -f "$ZDOTDIR/nvm-path.zsh" ]] && source "$ZDOTDIR/nvm-path.zsh"
