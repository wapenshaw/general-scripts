<#
.SYNOPSIS
    Returns $true if the winget CLI is on PATH, otherwise $false.

.DESCRIPTION
    Defines the Test-Winget helper used by other scripts to gate behavior that
    needs winget.

.EXAMPLE
    PS> if (Test-Winget) { winget upgrade }
#>

function Test-Winget {
    try {
        winget --version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}