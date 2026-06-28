<#
.SYNOPSIS
  Work-only aliases. Only sourced when $env:PS_WORK = '1'.
.DESCRIPTION
  Work module 03. Mirrors zsh's work/aliases.zsh.
#>

if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    Set-Alias -Name k -Value kubectl -Option AllScope -Force
}
if (Get-Command helm -ErrorAction SilentlyContinue) {
    Set-Alias -Name h -Value helm -Option AllScope -Force
}
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    Set-Alias -Name tf -Value terraform -Option AllScope -Force
}
