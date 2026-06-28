<#
.SYNOPSIS
  PSReadLine key handlers.
.DESCRIPTION
  Module 08 of the modular PowerShell profile. Depends on 01-07 + legacy
  functions (which are loaded before this module by the loader).
#>

try {
    # Tab → menu completion
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Ctrl+d → exit (like zsh)
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

    # Ctrl+Left/Right → move by word
    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord
    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord

    # Up/Down arrows → history search based on current input
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
} catch {
    Write-Warning "08-bindings: $($_.Exception.Message)"
}
