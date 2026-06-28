<#
.SYNOPSIS
  Environment variables, PATH additions, and PSReadLine option defaults.
.DESCRIPTION
  Module 02 of the modular PowerShell profile. Sets env vars and PATH that
  all subsequent modules depend on.
#>

# Editor
$env:EDITOR = if (Get-Command nvim -ErrorAction SilentlyContinue) { 'nvim' }
              elseif (Get-Command code -ErrorAction SilentlyContinue) { 'code --wait' }
              else { 'notepad' }

# Starship config location
$env:STARSHIP_CONFIG = Join-Path $HOME '.config/starship.toml'

# PSReadLine defaults
try {
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -EditMode Emacs
} catch {
    Write-Warning "02-exports: PSReadLine options failed: $($_.Exception.Message)"
}

# Add user-local bin to PATH if it exists
$userBin = Join-Path $HOME '.local\bin'
if ((Test-Path $userBin) -and ($env:PATH -notlike "*$userBin*")) {
    $env:PATH = "$userBin;$env:PATH"
}
