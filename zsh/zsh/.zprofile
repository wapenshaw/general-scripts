# Login-shell setup — runs once per session, before .zshrc.
# Work-specific SSH agent setup lives in work/ssh-agent.zsh (only present with --work).

[[ -f "$ZDOTDIR/work/ssh-agent.zsh" ]] && source "$ZDOTDIR/work/ssh-agent.zsh"
