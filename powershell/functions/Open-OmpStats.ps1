<#
.SYNOPSIS
    Starts a standalone omp stats dashboard and opens it in the browser.

.DESCRIPTION
    Runs `omp stats --port 0` so the OS picks a free port. A fixed port makes
    omp reuse or reclaim any dashboard already listening there, including one
    hosted inside a live omp session, so port 0 is the only launch that cannot
    touch other sessions.

    omp opens the dashboard itself (in the system browser, or in place of the
    block inside a Tern pane) and prints the URL. The dashboard runs in the
    foreground; press Ctrl+C to stop it.

.EXAMPLE
    PS> omp-stats
#>

function Open-OmpStats {
    [CmdletBinding()]
    param()

    $omp = Get-Command omp -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $omp) {
        Write-Error "omp was not found on PATH. Install it with Update-Omp."
        return
    }

    & $omp.Source stats --port 0
}

Set-Alias -Name omp-stats -Value Open-OmpStats -Scope Global -Force
