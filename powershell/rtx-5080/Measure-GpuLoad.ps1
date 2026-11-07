<#
.SYNOPSIS
    Logs NVIDIA GPU clocks, power, temperature and throttle reasons during a load run, then summarises them.

.DESCRIPTION
    Samples nvidia-smi once per second for -Seconds samples and writes them to a CSV
    named gpu-<Label>.csv in -OutputDirectory. Prints average/min/max for utilisation,
    core and memory clock, board power, temperature and fan speed (excluding the first
    -WarmupSeconds samples), plus a count of each clocks_event_reasons.active value.

    Start a repeatable load first (for example a looped 3DMark Steel Nomad run), then
    run this once per configuration with a distinct label to compare before/after.

    Common throttle reasons: 0x4 = software power cap, 0x20 = software thermal slowdown,
    0x1 = idle, 0x0 = none. nvidia-smi does not report core voltage on RTX 50 drivers;
    read it from mVolt+ or GPU-Z if needed.

.PARAMETER Label
    Name for this run; used in the CSV file name and the summary header.

.PARAMETER Seconds
    Number of one-second samples to record. Default 180.

.PARAMETER WarmupSeconds
    Leading samples excluded from the summary (clocks and temperature settle). Default 20.

.PARAMETER OutputDirectory
    Folder for the CSV. Default: current directory.

.EXAMPLE
    PS> .\Measure-GpuLoad.ps1 -Label stock
    PS> .\Measure-GpuLoad.ps1 -Label uv-2880 -Seconds 300 -OutputDirectory $env:TEMP

.NOTES
    Requires nvidia-smi on PATH (installed with the NVIDIA driver). No elevation needed.
    Record: devices/titan-rtx-5080.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Label,
    [ValidateRange(10, 86400)][int]$Seconds = 180,
    [ValidateRange(0, 3600)][int]$WarmupSeconds = 20,
    [string]$OutputDirectory = (Get-Location).Path
)

if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { throw 'nvidia-smi not found on PATH.' }
if ($WarmupSeconds -ge $Seconds) { throw '-WarmupSeconds must be less than -Seconds.' }

$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$out = Join-Path $OutputDirectory "gpu-$Label.csv"
$query = 'timestamp,utilization.gpu,clocks.gr,clocks.mem,power.draw,temperature.gpu,fan.speed,clocks_event_reasons.active'

Write-Verbose "Sampling $Seconds s into $out"
& nvidia-smi "--query-gpu=$query" --format=csv,noheader,nounits --loop-ms=1000 |
    Select-Object -First $Seconds |
    Set-Content -Path $out

$rows = Get-Content $out |
    ConvertFrom-Csv -Header ts, util, core, mem, power, temp, fan, reason |
    Select-Object -Skip $WarmupSeconds

function Get-Stat([string]$Name) {
    $m = $rows | ForEach-Object { [double]$_.$Name } | Measure-Object -Average -Minimum -Maximum
    '{0,-6} avg {1,8:N1}  min {2,8:N1}  max {3,8:N1}' -f $Name, $m.Average, $m.Minimum, $m.Maximum
}

"[$Label] samples=$($rows.Count) (after ${WarmupSeconds}s warmup)  file=$out"
'util', 'core', 'mem', 'power', 'temp', 'fan' | ForEach-Object { Get-Stat $_ }
'reasons: ' + (($rows | Group-Object reason | Sort-Object Count -Descending |
    ForEach-Object { "$($_.Name.Trim())=$($_.Count)" }) -join ', ')
