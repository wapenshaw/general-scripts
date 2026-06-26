# Login-shell setup — runs once per session, before .zshrc.
# Work-specific SSH agent setup lives in work/ssh-agent.zsh (only sourced
# when ZSH_WORK=1 in ~/.zshenv).

if [[ "${ZSH_WORK:-0}" == "1" && -f "$ZDOTDIR/work/ssh-agent.zsh" ]]; then
  source "$ZDOTDIR/work/ssh-agent.zsh"
fi
