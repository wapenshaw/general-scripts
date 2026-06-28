<#
.SYNOPSIS
  PSReadLine history configuration.
.DESCRIPTION
  Module 01 of the modular PowerShell profile. Loaded first — sets up history
  before any other module reads or writes it.
#>

try {
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally
    # Default history file is $env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
    # Increase max history entries
    Set-PSReadLineOption -MaximumHistoryCount 4096
} catch {
    Write-Warning "01-history: $($_.Exception.Message)"
}
