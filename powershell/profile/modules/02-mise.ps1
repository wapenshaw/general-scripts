<#
.SYNOPSIS
  Activate mise (runtime version manager) for the current shell.
.DESCRIPTION
  Module 02-mise of the modular PowerShell profile. Loads right after 02-exports
  so all subsequent modules see mise-managed runtimes (node, python, ruby, etc.)
  on PATH.

  mise replaces nvm/pyenv/rbenv. Config lives at ~/.config/mise/config.toml.
  Silent no-op if mise is not installed.
#>

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) { return }

try {
    mise activate pwsh | Out-String | Invoke-Expression
} catch {
    Write-Warning "02-mise: activation failed: $($_.Exception.Message)"
}