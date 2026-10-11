<#
.SYNOPSIS
    Activates the latest Visual Studio C++ toolchain for this process.
#>
function Enter-DevShell {
    [CmdletBinding()]
    param([ValidateSet('x64', 'x86', 'arm64')][string]$Architecture = 'x64')
    if ($env:VSCMD_VER) { throw 'Already in a developer shell. Open a fresh terminal to select another architecture.' }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio Installer was not found.' }
    $vsPath = & $vswhere -latest -prerelease -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vsPath) { throw 'No Visual Studio installation with C++ tools was found.' }
    Import-Module (Join-Path $vsPath 'Common7/Tools/Microsoft.VisualStudio.DevShell.dll') -Global -ErrorAction Stop
    Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-no_logo -arch=$Architecture -host_arch=x64" -ErrorAction Stop
}
Set-Alias -Name vsdev -Value Enter-DevShell -Scope Global -Force
