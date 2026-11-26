<#
.SYNOPSIS
  Assurant functions. Only sourced when $env:PS_ASSURANT = '1'.
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

# kubectl context shortcuts (same AKS contexts as zsh work/functions.zsh)
function kcontexts { kubectl config get-contexts }
function kcur      { kubectl config current-context }
function kdev      { kubectl config use-context aks-astra--dev; kubectl config current-context }
function kmodel    { kubectl config use-context aks-astra-model; Write-Warning 'MODEL context - treat as read-mostly.'; kubectl config current-context }
function kprod     { kubectl config use-context aks-astra-prod; Write-Warning 'PROD context - read-only unless explicitly approved.'; kubectl config current-context }
function kcheck    { kubectl config current-context; kubectl get nodes }
function kns       { param([Parameter(Mandatory)][string]$Namespace) kubectl config set-context --current --namespace $Namespace }
