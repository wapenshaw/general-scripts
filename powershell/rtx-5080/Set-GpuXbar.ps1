<#
.SYNOPSIS
    Sets only the RTX 5080 XBAR (crossbar) clock offset through the mVolt+ CLI, on top of an Afterburner curve.

.DESCRIPTION
    For long gaming sessions: Afterburner keeps the daily undervolt curve, memory and power
    limit, and this script adds an XBAR offset. mVolt+ only writes what is passed on the
    command line ("unspecified direct controls are left unchanged"), so Afterburner's
    settings stay as they are. mVolt+.exe exits right after the write; nothing keeps running.

    Measured 2026-11-04 on the Afterburner curve (2880 MHz @ 895 mV, +3000 memory, 111 %),
    Steel Nomad loop: XBAR +450 = +2.2 % FPS, +2.1 % 1 % lows, about 9 W less.
    +500 was the best step, +600 gave nothing more, +700 crashed Windows (bugcheck 0x133).

    The offset lasts until reboot, driver reset or -Reset.

.PARAMETER Offset
    XBAR offset in MHz. Default 450. Limited to 0-500 (the tested safe range).

.PARAMETER Reset
    Set XBAR back to stock (0).

.PARAMETER MVoltPath
    Path to mVolt+.exe. Default: C:\Software\mVolt+.exe.

.PARAMETER AdapterId
    mVolt+ adapter ID (from mVolt+.exe --list-gpus). Default: this TITAN's RTX 5080.

.EXAMPLE
    PS> .\Set-GpuXbar.ps1            # gaming session: XBAR +450
    PS> .\Set-GpuXbar.ps1 -Reset     # back to daily (XBAR 0)

.NOTES
    Requires an elevated session. Record: devices/titan-rtx-5080.md.
#>
#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Set')]
param(
    [Parameter(ParameterSetName = 'Set')][ValidateRange(0, 500)][int]$Offset = 450,
    [Parameter(ParameterSetName = 'Reset', Mandatory)][switch]$Reset,
    [string]$MVoltPath = 'C:\Software\mVolt+.exe',
    [string]$AdapterId = 'pci-2c0210de-41961458-00002c02-b01-s00'
)

if (-not (Test-Path -LiteralPath $MVoltPath)) { throw "mVolt+ not found at $MVoltPath." }
if ($Reset) { $Offset = 0 }
if (-not $PSCmdlet.ShouldProcess($AdapterId, "XBAR offset $Offset MHz")) { return }

# mVolt+.exe is a GUI-subsystem exe: PowerShell only waits for it when its output is piped.
$reply = & $MVoltPath --gpu-id $AdapterId --xbar-offset $Offset | Out-String
$ok = try { ($reply | ConvertFrom-Json).success } catch { $LASTEXITCODE -eq 0 }
if (-not $ok) { throw "mVolt+ write failed (exit $LASTEXITCODE): $($reply.Trim())" }

$s = & $MVoltPath --gpu-id $AdapterId --status | Out-String | ConvertFrom-Json
if ($s.xbar_offset_mhz -ne $Offset) { throw "Verification failed: XBAR offset is $($s.xbar_offset_mhz), expected $Offset." }
"XBAR offset $Offset MHz (live XBAR $($s.xbar_mhz) MHz). Lasts until reboot, driver reset or -Reset."
