# Homebrew (Linuxbrew) on PATH for bash and sh. Deployed to ~/.config/shell/brew.sh by
# linux/install.sh and sourced from ~/.profile and ~/.bashrc. zsh gets the same from
# ~/.zsh/.zshenv, which bash never reads (agent tools such as Copilot CLI run bash).
#
# Static on purpose: no `brew shellenv` fork, so it costs nothing per shell. Brewed tools
# go behind everything under $HOME (nvm's node, ~/.local/bin with uv's python, cargo, bun,
# tfenv) and ahead of the system dirs. Python and Node are never installed through brew.
# Safe to source repeatedly.

_brew_prefix=/home/linuxbrew/.linuxbrew

if [ -x "$_brew_prefix/bin/brew" ]; then
  export HOMEBREW_PREFIX="$_brew_prefix"
  export HOMEBREW_CELLAR="$_brew_prefix/Cellar"
  export HOMEBREW_REPOSITORY="$_brew_prefix/Homebrew"

  case ":${INFOPATH:-}:" in
    *":$_brew_prefix/share/info:"*) ;;
    *) export INFOPATH="$_brew_prefix/share/info:${INFOPATH:-}" ;;
  esac

  _brew_path=""
  _brew_placed=0
  _brew_ifs=$IFS
  IFS=:
  for _brew_dir in $PATH; do
    case $_brew_dir in
      "$_brew_prefix/bin" | "$_brew_prefix/sbin") continue ;;
    esac
    if [ "$_brew_placed" = 0 ]; then
      case $_brew_dir in
        "$HOME"/*) ;;
        *)
          _brew_path="${_brew_path:+$_brew_path:}$_brew_prefix/bin:$_brew_prefix/sbin"
          _brew_placed=1
          ;;
      esac
    fi
    _brew_path="${_brew_path:+$_brew_path:}$_brew_dir"
  done
  IFS=$_brew_ifs
  if [ "$_brew_placed" = 0 ]; then
    _brew_path="${_brew_path:+$_brew_path:}$_brew_prefix/bin:$_brew_prefix/sbin"
  fi
  export PATH="$_brew_path"
  unset _brew_path _brew_placed _brew_ifs _brew_dir
fi

unset _brew_prefix
