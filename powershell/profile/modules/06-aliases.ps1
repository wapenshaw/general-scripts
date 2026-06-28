<#
.SYNOPSIS
  Alias definitions.
.DESCRIPTION
  Module 06 of the modular PowerShell profile. Depends on 02-exports.
  Add new aliases here — keeps them in one place like zsh's aliases.zsh.
#>

# eza / ls replacement
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Set-Alias -Name ls -Value eza -Option AllScope -Force
}

# bat / cat replacement
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias -Name cat -Value bat -Option AllScope -Force
}

# rg / grep replacement
if (Get-Command rg -ErrorAction SilentlyContinue) {
    Set-Alias -Name grep -Value rg -Option AllScope -Force
}
