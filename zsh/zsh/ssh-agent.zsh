# Stable SSH agent socket for work login shells.
# Fixes a known socket path so VS Code, Git, and the shell all share the same agent.

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
_ssh_identity="$HOME/.ssh/id_ed25519_assurant"

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

case $- in
  *i*) _ssh_interactive=1 ;;
  *) _ssh_interactive=0 ;;
esac

if [ "$_ssh_interactive" -eq 1 ] && [ -t 0 ] && [ -r "${_ssh_identity}.pub" ]; then
  _ssh_identity_fingerprint="$(ssh-keygen -lf "${_ssh_identity}.pub" | awk '{print $2}')"
  if ! SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh-add -l 2>/dev/null | grep -Fq "$_ssh_identity_fingerprint"; then
    SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh-add "$_ssh_identity"
  fi
  unset _ssh_identity_fingerprint
fi

unset _ssh_agent_status _ssh_identity _ssh_interactive
