<#
.SYNOPSIS
  Assurant environment variables. Only sourced when $env:PS_ASSURANT = '1'.
.DESCRIPTION
  Work module 01. Mirrors zsh's work/exports.zsh.
#>

# Workspace
$env:ASTRA_HOME = Join-Path $HOME 'astra'

# Kubernetes
if (-not $env:KUBECONFIG) { $env:KUBECONFIG = Join-Path $HOME '.kube/config' }

# Corporate CA compatibility
$workCaFile = 'C:\Program Files\Common Files\SSL\cert.pem'
if (Test-Path -LiteralPath $workCaFile) {
    $env:SSL_CERT_FILE = $workCaFile
    $env:REQUESTS_CA_BUNDLE = $workCaFile
    $env:CURL_CA_BUNDLE = $workCaFile
    $env:NODE_EXTRA_CA_CERTS = $workCaFile
}

# Node.js — system CA + ipv4first to avoid WSL DNS hangs
$env:NODE_USE_SYSTEM_CA  = '1'
if ($env:NODE_OPTIONS -notmatch '--dns-result-order=') {
    $env:NODE_OPTIONS = ($env:NODE_OPTIONS + ' --dns-result-order=ipv4first').Trim()
}
