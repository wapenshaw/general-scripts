<#
.SYNOPSIS
    Installs omp (oh-my-pi) when it is missing, otherwise updates it.

.DESCRIPTION
    omp ships almost daily and has no winget package, so it stays on its
    official installer and updates itself (`omp update`; `update.auto` in
    ~/.omp/agent/config.yml covers updates between runs). Mirrors the omp
    handling in ai/standalone-cli.zsh for macOS and Linux.

    A missing omp is installed by running https://omp.sh/install.ps1 in a child
    Windows PowerShell, so the installer cannot end the calling session. The
    installer downloads a prebuilt omp.exe to %LOCALAPPDATA%\omp (or
    $env:PI_INSTALL_DIR), adds that folder to the User PATH and points omp at
    Git Bash. omp is always called by full path because PATH changes do not
    reach the current session.

    Returns $true on success and $false on failure; the tools' own output goes
    to the host. Supports -WhatIf.

.EXAMPLE
    PS> Update-Omp

.EXAMPLE
    PS> Update-Omp -WhatIf
#>

function Update-Omp {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param()

    $installDir = if ($env:PI_INSTALL_DIR) { $env:PI_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'omp' }
    $ompExe = Join-Path $installDir 'omp.exe'

    if (Test-Path -LiteralPath $ompExe -PathType Leaf) {
        if (-not $PSCmdlet.ShouldProcess($ompExe, 'omp update')) { return $true }

        $global:LASTEXITCODE = 0
        & $ompExe update | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "omp update exited $LASTEXITCODE"
            return $false
        }
        return $true
    }

    $installCommand = 'irm https://omp.sh/install.ps1 | iex'
    if (-not $PSCmdlet.ShouldProcess($installDir, "Install omp ($installCommand)")) { return $true }

    $global:LASTEXITCODE = 0
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $installCommand | Out-Host
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $ompExe -PathType Leaf)) {
        Write-Warning "omp installer failed (exit $LASTEXITCODE); expected $ompExe"
        return $false
    }

    Write-Host "omp: $(& $ompExe --version)"
    return $true
}
