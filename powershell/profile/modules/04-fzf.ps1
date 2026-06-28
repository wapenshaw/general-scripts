<#
.SYNOPSIS
  FZF environment variables. PSFzf key bindings are set by 09-plugins.ps1.
.DESCRIPTION
  Module 04 of the modular PowerShell profile. Depends on 02-exports.
#>

if (Get-Command fzf -ErrorAction SilentlyContinue) {
    $env:FZF_DEFAULT_COMMAND = if (Get-Command fd -ErrorAction SilentlyContinue) {
        'fd --type f --hidden --follow --exclude .git'
    } else {
        'Get-ChildItem -Recurse -File -Name'
    }
}
