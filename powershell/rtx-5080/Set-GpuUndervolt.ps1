<#
.SYNOPSIS
    Applies (or resets) the RTX 5080 tune — core offset + clock cap undervolt, memory, power limit and XBAR — through the mVolt+ CLI and verifies it.

.DESCRIPTION
    Undervolt without editing the curve:
      --core <CoreOffset>           shifts the whole stock curve up
      --clock-range 0,<MaxClock>    caps the clock, so the GPU stops at the lowest
                                    voltage point that reaches <MaxClock>
    plus --mem, --power and --xbar-offset in the same write.

    Defaults are the tune found on 2026-11-04 (devices/titan-rtx-5080.md):
      core +450, cap 3090 MHz, memory +3000, power 111 %, XBAR +400
      -> about 97 FPS vs 84 stock in a Steel Nomad loop, core about 3045 MHz at about 945 mV.
    XBAR +500 measured about 1 % faster, but +600 gave no gain and +700 crashed the
    whole system (bugcheck 0x133), so +400 keeps two steps of margin. Pass -XbarOffset 500
    to run the faster setting once it has passed a long soak test.

    -Preset Afterburner applies the old Afterburner-equivalent undervolt
    (core +468, cap 2880, memory 0, power 100, XBAR 0).

    After the write, the script re-reads mVolt+ --status and fails if any value did not
    stick. On driver 621.01+ mVolt+ can report success while the GPU keeps its old
    limits, so a zero exit code alone is not trusted.

    -Reset returns everything to stock: core 0, clock range released, memory 0,
    power 100 %, XBAR 0.

    Refuses to run while MSI Afterburner is running, because Afterburner re-applies its
    own profile at logon and after resume and would overwrite these settings.

.PARAMETER CoreOffset
    Core clock offset in MHz. Default 450. +550 regressed and +575 crashed at a 900 mV target.

.PARAMETER MaxClock
    Upper core clock limit in MHz (mVolt+ maximum 3090). Default 3090.

.PARAMETER MemOffset
    Memory clock offset in MHz. mVolt+ allows +3000 stock; with the BIOS override's memory
    maximum raised to 4999 (applied 2026-11-04) it accepts up to +4999. Default 3000.

.PARAMETER PowerPercent
    Power limit percent (69-111; 111 = 400 W). Default 111.

.PARAMETER XbarOffset
    XBAR (crossbar) clock offset in MHz. Default 400.

.PARAMETER Preset
    Afterburner = old core +468 / cap 2880 undervolt with everything else stock.

.PARAMETER Reset
    Return all tuned values to stock.

.PARAMETER MVoltPath
    Path to mVolt+.exe. Default: C:\Software\mVolt+.exe.

.PARAMETER AdapterId
    mVolt+ adapter ID (from mVolt+.exe --list-gpus). Default: this TITAN's RTX 5080.

.EXAMPLE
    PS> .\Set-GpuUndervolt.ps1                       # daily tune
    PS> .\Set-GpuUndervolt.ps1 -XbarOffset 500       # faster, soak-test first
    PS> .\Set-GpuUndervolt.ps1 -Preset Afterburner   # old cool/quiet undervolt
    PS> .\Set-GpuUndervolt.ps1 -Reset
    PS> .\Set-GpuUndervolt.ps1 -WhatIf

.NOTES
    Requires an elevated session (mVolt+ tuning writes need admin). Settings last until
    reboot or driver reset. Never enables the mVolt+ BIOS override. Record:
    devices/titan-rtx-5080.md.
#>
#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Apply')]
param(
    [Parameter(ParameterSetName = 'Apply')][ValidateRange(-1000, 1000)][int]$CoreOffset = 450,
    [Parameter(ParameterSetName = 'Apply')][ValidateRange(1500, 3090)][int]$MaxClock = 3090,
    [Parameter(ParameterSetName = 'Apply')][ValidateRange(-1000, 4999)][int]$MemOffset = 3000,
    [Parameter(ParameterSetName = 'Apply')][ValidateRange(69, 111)][int]$PowerPercent = 111,
    [Parameter(ParameterSetName = 'Apply')][ValidateRange(-1000, 1000)][int]$XbarOffset = 400,
    [Parameter(ParameterSetName = 'Preset', Mandatory)][ValidateSet('Afterburner')][string]$Preset,
    [Parameter(ParameterSetName = 'Reset', Mandatory)][switch]$Reset,
    [string]$MVoltPath = 'C:\Software\mVolt+.exe',
    [string]$AdapterId = 'pci-2c0210de-41961458-00002c02-b01-s00'
)

if (-not (Test-Path -LiteralPath $MVoltPath)) { throw "mVolt+ not found at $MVoltPath." }
if (Get-Process MSIAfterburner -ErrorAction SilentlyContinue) {
    throw 'MSI Afterburner is running. Quit it (tray -> Exit) first so it cannot overwrite these settings.'
}

if ($Preset -eq 'Afterburner') { $CoreOffset = 468; $MaxClock = 2880; $MemOffset = 0; $PowerPercent = 100; $XbarOffset = 0 }
if ($Reset) { $CoreOffset = 0; $MemOffset = 0; $PowerPercent = 100; $XbarOffset = 0 }

$range = if ($Reset) { 'default' } else { "0,$MaxClock" }
$cliArgs = @('--gpu-id', $AdapterId, '--core', "$CoreOffset", '--clock-range', $range,
    '--mem', "$MemOffset", '--power', "$PowerPercent", '--xbar-offset', "$XbarOffset")
$what = if ($Reset) { 'reset core, clock range, memory, power and XBAR to stock' } else {
    "core $CoreOffset MHz, cap $MaxClock MHz, memory $MemOffset MHz, power $PowerPercent %, XBAR $XbarOffset MHz" }

if (-not $PSCmdlet.ShouldProcess($AdapterId, $what)) { return }

# mVolt+.exe is a GUI-subsystem exe: PowerShell only waits for it when its output is piped.
$reply = & $MVoltPath @cliArgs | Out-String
$ok = try { ($reply | ConvertFrom-Json).success } catch { $LASTEXITCODE -eq 0 }
if (-not $ok) { throw "mVolt+ write failed (exit $LASTEXITCODE): $($reply.Trim())" }

$s = & $MVoltPath --gpu-id $AdapterId --status | Out-String | ConvertFrom-Json
$rangeOk = if ($Reset) { -not $s.clock_range_mhz.locked } else { $s.clock_range_mhz.locked -and $s.clock_range_mhz.max -eq $MaxClock }
$ok = $rangeOk -and $s.core_offset_mhz -eq $CoreOffset -and $s.memory_offset_mhz -eq $MemOffset -and
    $s.power_limit_percent -eq $PowerPercent -and $s.xbar_offset_mhz -eq $XbarOffset

'core {0} MHz, cap {1}-{2} MHz (locked={3}), memory {4} MHz, power {5} %, XBAR {6} MHz; live GPC {7} / XBAR {8} MHz' -f `
    $s.core_offset_mhz, $s.clock_range_mhz.min, $s.clock_range_mhz.max, $s.clock_range_mhz.locked,
    $s.memory_offset_mhz, $s.power_limit_percent, $s.xbar_offset_mhz, $s.gpc_mhz, $s.xbar_mhz
if (-not $ok) { throw 'Verification failed: mVolt+ status does not match the requested values.' }
"Verified: $what."
