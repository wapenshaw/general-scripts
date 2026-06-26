# Work login-shell setup — runs once per session, before .zshrc.
# Establishes the SSH agent socket at a fixed path so VS Code, Git, and
# keychain all share the same agent across the WSL session.

source "$ZDOTDIR/work/ssh-agent.zsh"
