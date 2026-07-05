<#
.SYNOPSIS
  PSReadLine completion options and argument completers.
.DESCRIPTION
  Module 03 of the modular PowerShell profile. Depends on 02-exports (PSReadLine loaded).

  Predictive IntelliSense is OFF by default (security: no history leaked on
  screen). Press F2 to cycle: Off → Inline → ListView → Off.
  Ctrl+R (reverse history search) works independently and is always available.
#>

try {
    # Default: prediction OFF. History is still searchable via Ctrl+R.
    Set-PSReadLineOption -PredictionSource None
} catch {
    # PredictionSource may not be available on older PSReadLine — ignore.
}

# F2 cycles prediction: Off → Inline → ListView → Off.
# No InvokePrompt() call — Set-PSReadLineOption takes effect on the next
# keystroke cleanly. (InvokePrompt causes encoding garbage on Unicode
# prompts — see PSReadLine issue #2866.)
try {
    Set-PSReadLineKeyHandler -Key F2 -BriefDescription 'TogglePrediction' `
        -LongDescription 'Cycle prediction: Off → Inline → ListView → Off' `
        -ScriptBlock {
            $opts = Get-PSReadLineOption
            if ($opts.PredictionSource -eq 'None') {
                try { Set-PSReadLineOption -PredictionSource HistoryAndPlugin }
                catch { Set-PSReadLineOption -PredictionSource History }
                Set-PSReadLineOption -PredictionViewStyle InlineView
            }
            elseif ($opts.PredictionViewStyle -eq 'InlineView') {
                Set-PSReadLineOption -PredictionViewStyle ListView
            }
            else {
                Set-PSReadLineOption -PredictionSource None
            }
        }
} catch {}
