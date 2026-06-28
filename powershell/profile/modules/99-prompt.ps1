<#
.SYNOPSIS
  Starship prompt initialisation. Loaded LAST, after all other modules.
.DESCRIPTION
  Module 99 of the modular PowerShell profile. Mirrors zsh's prompt.zsh
  placement — the prompt must capture all env vars, PATH additions, and
  functions set by earlier modules.
#>

if (Get-Command starship -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression (&starship init powershell)
    } catch {
        Write-Warning "99-prompt: starship init failed: $($_.Exception.Message)"
    }
}
