# Stable SSH agent socket for login shells.
# Fixes a known socket path so VS Code, Git, and the shell all share the same agent.

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

if [ -S "$SSH_AUTH_SOCK" ]; then
  SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh-add -l >/dev/null 2>&1
  _ssh_agent_status=$?
else
  _ssh_agent_status=2
fi

# Exit code 2 = no reachable agent — start a new one bound to the fixed socket
if [ "$_ssh_agent_status" -eq 2 ]; then
  rm -f "$SSH_AUTH_SOCK" "$HOME/.ssh/agent.env"
  ssh-agent -a "$SSH_AUTH_SOCK" > "$HOME/.ssh/agent.env"
  . "$HOME/.ssh/agent.env" >/dev/null
fi

unset _ssh_agent_status
