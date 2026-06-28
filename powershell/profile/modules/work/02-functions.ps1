<#
.SYNOPSIS
  Work-only functions. Only sourced when $env:PS_WORK = '1'.
.DESCRIPTION
  Work module 02. Mirrors zsh's work/functions.zsh.
#>

# Azure login helpers
function azfit {
    <# .SYNOPSIS Login to Azure with tenant from az.env #>
    if (Test-Path (Join-Path $PSScriptRoot '04-az.env.ps1')) {
        . (Join-Path $PSScriptRoot '04-az.env.ps1')
    }
    if ($env:AZ_TENANT_ID) {
        az login --tenant $env:AZ_TENANT_ID
    } else {
        Write-Warning 'azfit: AZ_TENANT_ID not set. Fill in work/04-az.env.ps1 first.'
    }
}

# kubectl context shortcuts
function kdev  { kubectl config use-context dev }
function kprod { kubectl config use-context prod }
function kns   { param($ns) kubectl config set-context --current --namespace $ns }
