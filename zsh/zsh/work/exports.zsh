# Assurant environment — only sourced when installed with --assurant.
# Corporate CA trust, workspace paths, Kubernetes config, Node TLS hardening.

# Workspace
export ASTRA_HOME="$HOME/astra"

# Kubernetes
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

# Corporate CA compatibility (Assurant). Linux and macOS use different
# system/Homebrew bundle locations.
_ca_bundle=''
if [[ "$OSTYPE" == darwin* ]]; then
  _ca_bundle='/etc/ssl/cert.pem'
  if [[ ! -r "$_ca_bundle" ]] && (( $+commands[brew] )); then
    _brew_prefix="$(brew --prefix)"
    [[ -r "$_brew_prefix/etc/ca-certificates/cert.pem" ]] && _ca_bundle="$_brew_prefix/etc/ca-certificates/cert.pem"
  fi
else
  _ca_bundle='/etc/ssl/certs/ca-certificates.crt'
fi

if [[ -r "$_ca_bundle" ]]; then
  export SSL_CERT_FILE="$_ca_bundle"
  export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
  export CURL_CA_BUNDLE="$SSL_CERT_FILE"
  export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
  export npm_config_cafile="$SSL_CERT_FILE"
fi

# Node.js — NODE_USE_SYSTEM_CA covers CA trust; ipv4first avoids WSL DNS hangs
export NODE_USE_SYSTEM_CA=1
[[ "$OSTYPE" != darwin* ]] && export NODE_OPTIONS="--use-system-ca --dns-result-order=ipv4first"

# npm
export npm_config_strict_ssl=true

# Remove Windows Node pollution from WSL PATH
path=(${path:#/mnt/c/Program\ Files/nodejs/*})

unset _ca_bundle _brew_prefix
