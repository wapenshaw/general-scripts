# Work login-shell setup — runs once per session, before .zshrc.
# Reuse the shared SSH agent module so VS Code, Git, and the shell keep
# the same fixed socket across the WSL session.

source "$ZDOTDIR/ssh-agent.zsh"
