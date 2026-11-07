<#
.SYNOPSIS
    Shows the RTX 5080's current tuning state: mVolt+ status, driver/VBIOS and whether Afterburner is active.

.DESCRIPTION
    Read-only snapshot used before and after every tuning change:
      - mVolt+ --status (profile, power limit, core/memory offsets, rail offsets in mV,
        clock-range lock, live clocks)
      - nvidia-smi driver, VBIOS and live clock/power/temperature/throttle reason
      - MSI Afterburner / RTSS processes and the \MSIAfterburner logon task
    Use -Raw to get the full mVolt+ status object instead of the summary.

.PARAMETER MVoltPath
    Path to mVolt+.exe. Default: C:\Software\mVolt+.exe.

.PARAMETER Raw
    Return the full mVolt+ status object.

.EXAMPLE
    PS> .\Get-GpuTuneState.ps1
    PS> (.\Get-GpuTuneState.ps1 -Raw).clock_range_mhz

.NOTES
    mVolt+ --status needs no elevation. The status JSON reports voltages in microvolts;
    this script converts them to mV. Record: devices/titan-rtx-5080.md.
#>
[CmdletBinding()]
param(
    [string]$MVoltPath = 'C:\Software\mVolt+.exe',
    [switch]$Raw
)

if (-not (Test-Path -LiteralPath $MVoltPath)) { throw "mVolt+ not found at $MVoltPath." }

$status = & $MVoltPath --status | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $status) { throw "mVolt+ --status failed (exit $LASTEXITCODE)." }
if ($Raw) { return $status }

function ConvertTo-MvOffsets($o) { 'VMIN {0}, REL {1}, ALT {2}, OV {3} mV' -f ($o.vmin / 1000), ($o.rel / 1000), ($o.alt / 1000), ($o.ov / 1000) }

'== mVolt+ =='
[pscustomobject]@{
    GPU          = "$($status.gpu) (VBIOS $($status.vbios))"
    AdapterId    = $status.adapter_id
    Profile      = $status.active_profile
    PowerLimit   = '{0} % ({1} W enforced)' -f $status.power_limit_percent, ($status.power_limits.enforced_mw / 1000)
    CoreOffset   = "$($status.core_offset_mhz) MHz"
    MemoryOffset = "$($status.memory_offset_mhz) MHz"
    NVVDD        = ConvertTo-MvOffsets $status.nvvdd_offsets_uv
    MSVDD        = ConvertTo-MvOffsets $status.msvdd_offsets_uv
    ClockRange   = '{0}-{1} MHz, locked={2}' -f $status.clock_range_mhz.min, $status.clock_range_mhz.max, $status.clock_range_mhz.locked
    BoostLock    = $status.boost_lock
    LiveClocks   = 'GPC {0} / XBAR {1} / SYS {2} MHz' -f $status.gpc_mhz, $status.xbar_mhz, $status.sys_mhz
} | Format-List | Out-String

'== nvidia-smi =='
& nvidia-smi --query-gpu=driver_version,vbios_version,clocks.gr,clocks.mem,power.draw,temperature.gpu,fan.speed,clocks_event_reasons.active --format=csv

''
'== Afterburner =='
$procs = Get-Process MSIAfterburner, RTSS -ErrorAction SilentlyContinue
if ($procs) { $procs | Select-Object Name, Id | Format-Table -AutoSize | Out-String } else { 'Afterburner/RTSS not running.' }
$task = Get-ScheduledTask -TaskName MSIAfterburner -ErrorAction SilentlyContinue
if ($task) { "Logon task \MSIAfterburner: $($task.State)" } else { 'No \MSIAfterburner logon task.' }
