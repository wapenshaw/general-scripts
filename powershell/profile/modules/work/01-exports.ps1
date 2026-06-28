<#
.SYNOPSIS
  Work-only environment variables. Only sourced when $env:PS_WORK = '1'.
.DESCRIPTION
  Work module 01. Mirrors zsh's work/exports.zsh.
#>

# Workspace
$env:ASTRA_HOME = Join-Path $HOME 'astra'

# Kubernetes
if (-not $env:KUBECONFIG) { $env:KUBECONFIG = Join-Path $HOME '.kube/config' }

# Corporate CA compatibility
$env:SSL_CERT_FILE      = 'C:\Program Files\Common Files\SSL\cert.pem'
$env:REQUESTS_CA_BUNDLE = $env:SSL_CERT_FILE
$env:CURL_CA_BUNDLE     = $env:SSL_CERT_FILE

# Node.js — system CA + ipv4first to avoid WSL DNS hangs
$env:NODE_USE_SYSTEM_CA  = '1'
$env:NODE_EXTRA_CA_CERTS = $env:SSL_CERT_FILE
$env:NODE_OPTIONS        = '--dns-result-order=ipv4first'
