<#
.SYNOPSIS
  Visual Studio Developer Shell activation (vcvars64 equivalent).
.DESCRIPTION
  Module 11 of the modular PowerShell profile. Activates the VS Developer
  Shell so the MSVC compiler, Windows SDK headers/libs, and related tools are
  on PATH and the INCLUDE/LIB env vars are set — the same state as a
  "x64 Native Tools Command Prompt for VS".

  Replaces the fragile `cmd.exe /c vcvars64.bat && set` pipe hack: uses
  vswhere to discover the latest VS install (works for VS 2022 v17 and
  VS 2026 v18 without hardcoding paths), then imports the official
  Microsoft.VisualStudio.DevShell.dll and calls Enter-VsDevShell in-process.

  Silent no-op when Visual Studio is not installed — safe on a fresh box
  that has not yet run the winget/VS install step. Idempotent: skips
  re-activation when $env:VSCMD_VER is already set (e.g. shell launched
  from a VS Developer PowerShell prompt).
.NOTES
  No admin required. Activation is global to the process (the DevShell module
  has no Exit-VsDevShell); this matches the old vcvars64.bat behaviour.
#>

# Idempotency: if already in a VS Dev Shell (e.g. launched from VS Terminal),
# don't re-activate — Enter-VsDevShell is not cheap and re-running can double
# up PATH entries.
if ($env:VSCMD_VER) { return }

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) { return }

# Locate the latest VS with the C++ workload. -prerelease picks up VS 2026
# Insiders/Preview; -products * matches any edition (Community/Pro/Enterprise/
# BuildTools). Version-agnostic: works for VS 2022 (v17) and VS 2026 (v18).
$vsPath = & $vswhere -latest -prerelease -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $vsPath) { return }

$devShellDll = Join-Path $vsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
if (-not (Test-Path -LiteralPath $devShellDll)) { return }

try {
    Import-Module $devShellDll -ErrorAction Stop
    # -SkipAutomaticLocation: don't CD into ~/source/repos.
    # -DevCmdArguments "-no_logo": silence the VsDevCmd.bat banner.
    $null = Enter-VsDevShell -VsInstallPath $vsPath `
        -SkipAutomaticLocation `
        -DevCmdArguments '-no_logo' `
        -ErrorAction Stop
} catch {
    Write-Warning "11-vsdev: Enter-VsDevShell failed: $($_.Exception.Message)"
}