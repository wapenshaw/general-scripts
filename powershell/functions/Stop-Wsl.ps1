<#
.SYNOPSIS
    Shuts WSL down and disables its service so nothing can start it until Start-Wsl.

.DESCRIPTION
    Runs `wsl --shutdown`, then stops WSLService and sets it to Disabled. While it is
    disabled, any wsl.exe call fails with Wsl/ERROR_SERVICE_DISABLED instead of silently
    booting the VM, which is what happens when an editor, Docker Desktop or a tool such as
    Herdr calls wsl.exe. Use -ShutdownOnly to keep the service enabled. Needs an elevated
    session because it changes a service. Undo with Start-Wsl.

.PARAMETER ShutdownOnly
    Only run `wsl --shutdown`; leave WSLService as it is.

.EXAMPLE
    PS> Stop-Wsl

.EXAMPLE
    PS> Stop-Wsl -WhatIf
#>

function Stop-Wsl {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$ShutdownOnly
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $ShutdownOnly -and -not $isAdmin) {
        Write-Error 'Stop-Wsl changes a service and needs an elevated PowerShell (or use -ShutdownOnly).'
        return
    }

    if ($PSCmdlet.ShouldProcess('WSL', 'Shut down all distributions')) {
        & wsl.exe --shutdown
    }
    if ($ShutdownOnly) { return }

    if ($PSCmdlet.ShouldProcess('WSLService', 'Stop and disable')) {
        Set-Service -Name WSLService -StartupType Disabled
        Stop-Service -Name WSLService -Force
        Write-Host 'WSL is off and cannot start until Start-Wsl.'
    }
}
