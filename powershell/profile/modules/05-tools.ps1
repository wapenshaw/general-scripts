<#
.SYNOPSIS
  Tool initialisation: zoxide, WinGet CommandNotFound.
.DESCRIPTION
  Module 05 of the modular PowerShell profile. Every init is guarded by
  Get-Command + try/catch so a missing tool never breaks the shell.
#>

# WinGet CommandNotFound — suggests winget packages for unknown commands
try {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop
} catch {
    # Module ships with App Installer; not critical if missing
}

# zoxide — smart cd
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    try {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Warning "05-tools: zoxide init failed: $($_.Exception.Message)"
    }
}
