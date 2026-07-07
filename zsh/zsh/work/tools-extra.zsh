# Work shells should always point at the fixed agent socket.
# The login-shell ssh-agent module owns starting the agent and loading keys.

export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
