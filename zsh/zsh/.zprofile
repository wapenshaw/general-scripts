# Login-shell setup — runs once per session, before .zshrc.
# Sets up a stable SSH agent socket at ~/.ssh/agent.sock so zsh, VS Code,
# and git all share the same agent.

source "$ZDOTDIR/ssh-agent.zsh"
