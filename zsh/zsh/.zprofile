# Login-shell setup — runs once per session, before .zshrc.
# Homebrew's primary setup is in .zshenv (so non-interactive shells get it).
# macOS's /etc/zprofile runs path_helper AFTER .zshenv and moves Homebrew behind
# /usr/bin in login shells, so re-apply it here to keep Homebrew tools first.
# typeset -U keeps PATH free of duplicates.
typeset -U path PATH
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$_brew" ]]; then eval "$("$_brew" shellenv zsh)"; break; fi
done
unset _brew

# Assurant profile only: stable SSH agent socket at ~/.ssh/agent.sock
# so zsh, VS Code, and git share the same agent.
if [[ "${ZSH_ASSURANT:-0}" == "1" && -f "$ZDOTDIR/ssh-agent.zsh" ]]; then
  source "$ZDOTDIR/ssh-agent.zsh"
fi
