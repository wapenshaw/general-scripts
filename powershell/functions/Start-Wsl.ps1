<#
.SYNOPSIS
    Re-enables the WSL service and boots a distro, for setups where WSL is kept off until wanted.

.DESCRIPTION
    Pairs with Stop-Wsl. Stop-Wsl shuts WSL down and disables WSLService, so no stray wsl.exe
    call (an editor, Docker Desktop, Herdr, a script) can boot the VM. Start-Wsl turns it back
    on: sets WSLService to Manual, starts it, then boots the distro so the first interactive
    command is fast. Needs an elevated session because it changes a service.

.PARAMETER Distro
    Distribution to boot. Defaults to Ubuntu.

.EXAMPLE
    PS> Start-Wsl

.EXAMPLE
    PS> Start-Wsl -WhatIf
#>

function Start-Wsl {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Distro = 'Ubuntu'
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error 'Start-Wsl changes a service and needs an elevated PowerShell.'
        return
    }

    if ($PSCmdlet.ShouldProcess('WSLService', 'Set to Manual and start')) {
        Set-Service -Name WSLService -StartupType Manual
        Start-Service -Name WSLService
    }
    if ($PSCmdlet.ShouldProcess($Distro, 'Boot distribution')) {
        & wsl.exe -d $Distro -e true
        if ($LASTEXITCODE -ne 0) {
            Write-Error "wsl.exe could not start '$Distro' (exit code $LASTEXITCODE)."
            return
        }
        Write-Host "WSL is running ($Distro). Stop-Wsl shuts it down and blocks automatic starts again."
    }
}
