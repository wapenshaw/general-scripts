<#
.SYNOPSIS
  PSReadLine completion options and argument completers.
.DESCRIPTION
  Module 03 of the modular PowerShell profile. Depends on 02-exports (PSReadLine loaded).
#>

try {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
} catch {
    # PredictionSource may not be available on older PSReadLine
    try { Set-PSReadLineOption -PredictionSource History } catch {}
}
