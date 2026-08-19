# Login-shell setup — runs once per session, before .zshrc.
# Homebrew's shellenv used to live in ~/.zprofile. Once ZDOTDIR points at
# ~/.config/zsh, that file is no longer read, so initialize Homebrew here.
if [[ "$OSTYPE" == darwin* ]]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$_brew" ]]; then
      eval "$("$_brew" shellenv zsh)"
      break
    fi
  done
  unset _brew
fi

# Assurant profile only: stable SSH agent socket at ~/.ssh/agent.sock
# so zsh, VS Code, and git share the same agent.
if [[ "${ZSH_ASSURANT:-0}" == "1" && -f "$ZDOTDIR/ssh-agent.zsh" ]]; then
  source "$ZDOTDIR/ssh-agent.zsh"
fi
