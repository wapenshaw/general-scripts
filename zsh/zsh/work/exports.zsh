# Work-specific environment — only sourced when installed with --work.
# Corporate CA trust, workspace paths, Kubernetes config, Node TLS hardening.

# Workspace
export ASTRA_HOME="$HOME/astra"

# Kubernetes
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Corporate CA compatibility (Assurant)
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
export CURL_CA_BUNDLE="$SSL_CERT_FILE"

# Node.js — NODE_USE_SYSTEM_CA covers CA trust; ipv4first avoids WSL DNS hangs
export NODE_USE_SYSTEM_CA=1
export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
export NODE_OPTIONS="--dns-result-order=ipv4first"

# npm
export npm_config_cafile="$SSL_CERT_FILE"
export npm_config_strict_ssl=true

# Remove Windows Node pollution from WSL PATH
path=(${path:#/mnt/c/Program\ Files/nodejs/*})
