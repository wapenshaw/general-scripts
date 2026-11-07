<#
.SYNOPSIS
    Steps the RTX 5080 through mVolt+ tuning configurations under a running load and measures FPS, clocks and power for each.

.DESCRIPTION
    For every step: applies core offset / voltage target / memory offset / power limit
    through the mVolt+ CLI, verifies the write with --status, waits -SettleSeconds,
    then measures for -MeasureSeconds:
      - FPS and 1% low from PresentMon (frame times of -ProcessName)
      - core/memory clock, board power, temperature, fan and throttle reason from nvidia-smi
    and appends one row per step to sweep-<timestamp>.csv in -OutputDirectory.

    Voltage targeting: a step gives TargetMv instead of an explicit MaxClock. The
    script looks up the stock V/F curve clock at that voltage and sets
    --clock-range 0,(stock clock + Core). The GPU then stops at that voltage point.
    EffectiveMv in the output is inferred: the lowest curve voltage whose
    (stock clock + Core) reaches the measured average clock. It is not a sensor reading.

    Crash handling: if the load process exits, an nvlddmkm/Display event is logged
    (driver reset, TDR), FPS falls below 50 % of the first step's FPS, or an mVolt+
    write fails, the script applies -SafeStep, records the failure, and stops.

.PARAMETER Steps
    Array of hashtables: @{ Name='o500-925'; Core=500; TargetMv=925; Mem=0; Power=100 }.
    Use MaxClock instead of TargetMv for an explicit cap, or Stock=$true for stock
    (core 0, clock range released, memory 0, power 100).

.PARAMETER SafeStep
    Applied on a crash and at the end if -RestoreSafe. Default: the known-good
    Afterburner-equivalent undervolt (core +468, cap 2880, memory 0, power 100).

.PARAMETER ProcessName
    Load process to watch and capture frames from. Default 3DMarkSteelNomad.exe.

.EXAMPLE
    PS> $s = 500,525,550 | ForEach-Object { @{ Name="o$_-925"; Core=$_; TargetMv=925 } }
    PS> .\Invoke-GpuTuneSweep.ps1 -Steps $s -OutputDirectory $env:TEMP\gpu-runs

.NOTES
    Requires an elevated session, mVolt+ (C:\Software\mVolt+.exe) and PresentMon CLI
    (C:\Software\PresentMon\PresentMon-*-x64.exe, from github.com/GameTechDev/PresentMon).
    Quit MSI Afterburner first. Short steps don't prove stability: soak-test the
    winner. Record: devices/titan-rtx-5080.md.
#>
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory)][hashtable[]]$Steps,
    [int]$SettleSeconds = 20,
    [int]$MeasureSeconds = 140,   # 2 full Steel Nomad loops (~70 s each)
    [string]$ProcessName = '3DMarkSteelNomad.exe',
    [string]$OutputDirectory = (Get-Location).Path,
    [hashtable]$SafeStep = @{ Name = 'safe'; Core = 468; MaxClock = 2880; Mem = 0; Power = 100 },
    [switch]$RestoreSafe,
    [string]$MVoltPath = 'C:\Software\mVolt+.exe',
    [string]$PresentMonPath = (Get-ChildItem 'C:\Software\PresentMon\PresentMon-*-x64.exe' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName),
    [string]$AdapterId = 'pci-2c0210de-41961458-00002c02-b01-s00'
)

# Stock V/F curve (mV -> MHz), decoded from Afterburner [Defaults] on 2026-11-04,
# driver 621.01, VBIOS 98.03.3b.40.11. Shifts a few MHz with temperature.
# Plain hashtable on purpose: an [ordered] dictionary treats $d[925] as a positional index.
$StockCurve = @{
    800 = 1875; 810 = 2010; 815 = 2062; 820 = 2092; 825 = 2122; 835 = 2152; 840 = 2182; 845 = 2205
    850 = 2235; 860 = 2257; 865 = 2287; 870 = 2317; 875 = 2340; 885 = 2362; 890 = 2392; 895 = 2415
    900 = 2445; 910 = 2467; 915 = 2490; 920 = 2512; 925 = 2535; 935 = 2565; 940 = 2587; 945 = 2602
    950 = 2625; 960 = 2647; 965 = 2670; 970 = 2685; 975 = 2707; 985 = 2722; 990 = 2745; 995 = 2760
    1000 = 2797; 1010 = 2820; 1015 = 2835; 1020 = 2850; 1025 = 2865; 1035 = 2880; 1040 = 2887
}

$CurveMv = [int[]]($StockCurve.Keys | Sort-Object)

foreach ($p in $MVoltPath, $PresentMonPath) { if (-not $p -or -not (Test-Path -LiteralPath $p)) { throw "Missing tool: $p" } }
if (Get-Process MSIAfterburner -ErrorAction SilentlyContinue) { throw 'Quit MSI Afterburner first.' }
$procBase = [IO.Path]::GetFileNameWithoutExtension($ProcessName)
if (-not (Get-Process $procBase -ErrorAction SilentlyContinue)) { throw "$ProcessName is not running. Start the load first." }

$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultCsv = Join-Path $OutputDirectory "sweep-$stamp.csv"

function Get-CurveClock([int]$Mv) {
    $key = $CurveMv | Where-Object { $_ -le $Mv } | Select-Object -Last 1
    if ($null -eq $key) { throw "TargetMv $Mv below curve table." }
    [int]$StockCurve[$key]
}

function Get-EffectiveMv([double]$Clock, [int]$Core) {
    $hit = $CurveMv | Where-Object { $StockCurve[$_] + $Core -ge $Clock - 7 } | Select-Object -First 1
    if ($null -eq $hit) { '>1040' } else { $hit }
}

function Set-Step([hashtable]$S) {
    if ($S.Stock) {
        $a = @('--gpu-id', $AdapterId, '--core', '0', '--clock-range', 'default', '--mem', '0', '--power', '100')
        $max = $null
    } else {
        $max = if ($S.MaxClock) { [int]$S.MaxClock } else { (Get-CurveClock $S.TargetMv) + [int]$S.Core }
        if ($max -lt 1500) { throw "Computed max clock $max MHz is implausible; refusing to apply." }
        $max = [math]::Min($max, 3090)   # mVolt+ clock_range_mhz.limit_max on this card
        $mem = if ($null -ne $S.Mem) { [int]$S.Mem } else { 0 }
        $pwr = if ($null -ne $S.Power) { [int]$S.Power } else { 100 }
        $xbar = if ($null -ne $S.Xbar) { [int]$S.Xbar } else { 0 }
        $xvd = if ($null -ne $S.XbarVdemand) { [int]$S.XbarVdemand } else { 0 }
        $a = @('--gpu-id', $AdapterId, '--core', "$($S.Core)", '--clock-range', "0,$max", '--mem', "$mem", '--power', "$pwr",
            '--xbar-offset', "$xbar", '--xbar-vdemand', "$xvd")
    }
    if ($S.Stock) { $a += @('--xbar-offset', '0', '--xbar-vdemand', '0') }
    # mVolt+.exe is a GUI-subsystem exe: PowerShell only waits for it when its output is piped.
    $reply = & $MVoltPath @a | Out-String
    $ok = try { ($reply | ConvertFrom-Json).success } catch { $LASTEXITCODE -eq 0 }
    if (-not $ok) { throw "mVolt+ write failed (exit $LASTEXITCODE): $($a -join ' ') :: $($reply.Trim())" }
    $st = & $MVoltPath --gpu-id $AdapterId --status | Out-String | ConvertFrom-Json
    if (-not $S.Stock) {
        if ($st.core_offset_mhz -ne [int]$S.Core -or $st.clock_range_mhz.max -ne $max -or $st.memory_offset_mhz -ne $mem -or
            $st.power_limit_percent -ne $pwr -or $st.xbar_offset_mhz -ne $xbar -or $st.voltage_demand_mv.Xbar -ne $xvd) {
            throw "Verification failed for $($S.Name): core $($st.core_offset_mhz) max $($st.clock_range_mhz.max) mem $($st.memory_offset_mhz) power $($st.power_limit_percent) xbar $($st.xbar_offset_mhz) xbar-vdemand $($st.voltage_demand_mv.Xbar)"
        }
    }
    $max
}

function Test-DriverReset([datetime]$Since) {
    @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $Since } -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -match 'nvlddmkm' -or ($_.ProviderName -eq 'Display' -and $_.Id -eq 4101) }).Count -gt 0
}

$results = [System.Collections.Generic.List[object]]::new()
$firstFps = $null

foreach ($step in $Steps) {
    $name = if ($step.Name) { $step.Name } else { "c$($step.Core)-v$($step.TargetMv)" }
    $t0 = Get-Date
    $row = [ordered]@{ Time = $t0.ToString('HH:mm:ss'); Step = $name; Core = $step.Core; TargetMv = $step.TargetMv; MaxClock = $null
        Mem = $step.Mem; Power = $step.Power; Xbar = $step.Xbar; XbarVdemand = $step.XbarVdemand; XbarMhz = $null; Fps = $null; Low1 = $null; ClockAvg = $null; ClockMin = $null; PowerW = $null
        TempC = $null; Fan = $null; MemClock = $null; EffectiveMv = $null; Reasons = $null; Result = 'ok' }
    try {
        $row.MaxClock = Set-Step $step
        Write-Host "[$($row.Time)] $name applied (max $($row.MaxClock)); settling $SettleSeconds s"
        for ($i = 0; $i -lt $SettleSeconds; $i += 2) {
            Start-Sleep -Seconds 2
            if (Test-DriverReset $t0) { throw 'Driver reset event during settle' }
            if (-not (Get-Process $procBase -ErrorAction SilentlyContinue)) { throw "$ProcessName exited during settle" }
        }

        $smiFile = Join-Path $OutputDirectory "sweep-$stamp-$name-smi.csv"
        $pmFile = Join-Path $OutputDirectory "sweep-$stamp-$name-pm.csv"
        $smi = Start-Process nvidia-smi -PassThru -WindowStyle Hidden -ArgumentList @(
            '--query-gpu=clocks.gr,clocks.mem,power.draw,temperature.gpu,fan.speed,clocks_event_reasons.active',
            '--format=csv,noheader,nounits', '--loop-ms=1000', '-f', "`"$smiFile`"")
        $pm = Start-Process $PresentMonPath -PassThru -WindowStyle Hidden -ArgumentList @(
            '--process_name', $ProcessName, '--output_file', "`"$pmFile`"", '--timed', "$MeasureSeconds",
            '--terminate_after_timed', '--no_console_stats', '--stop_existing_session', '--session_name', 'GpuTuneSweep')
        # Poll every 2 s so a crash is reverted within seconds, not after the full window.
        $crash = $null
        while (-not $pm.HasExited) {
            Start-Sleep -Seconds 2
            if (-not (Get-Process $procBase -ErrorAction SilentlyContinue)) { $crash = "$ProcessName exited (crash?)" }
            elseif (Test-DriverReset $t0) { $crash = 'Driver reset event (nvlddmkm / Display 4101) logged' }
            if ($crash) {
                Stop-Process -Id $pm.Id -Force -ErrorAction SilentlyContinue
                $null = & $PresentMonPath --terminate_existing_session --session_name GpuTuneSweep 2>&1
                break
            }
        }
        Stop-Process -Id $smi.Id -Force -ErrorAction SilentlyContinue
        if ($crash) { throw $crash }
        try {
            $live = & $MVoltPath --gpu-id $AdapterId --status | Out-String | ConvertFrom-Json
            $row.XbarMhz = $live.xbar_mhz
        } catch { }

        if (-not (Get-Process $procBase -ErrorAction SilentlyContinue)) { throw "$ProcessName exited (crash?)" }
        if (Test-DriverReset $t0) { throw 'Driver reset event (nvlddmkm / Display 4101) logged' }

        $ft = @(Import-Csv $pmFile | ForEach-Object { [double]$_.MsBetweenPresents } | Where-Object { $_ -gt 0 })
        if ($ft.Count -lt 100) { throw "Only $($ft.Count) frames captured" }
        $row.Fps = [math]::Round(1000 / ($ft | Measure-Object -Average).Average, 2)
        $worst = $ft | Sort-Object -Descending | Select-Object -First ([math]::Max(1, [int]($ft.Count / 100)))
        $row.Low1 = [math]::Round(1000 / ($worst | Measure-Object -Average).Average, 2)

        $smiRows = @(Get-Content $smiFile | ConvertFrom-Csv -Header core, mem, power, temp, fan, reason)
        $c = $smiRows | ForEach-Object { [double]$_.core } | Measure-Object -Average -Minimum
        $row.ClockAvg = [math]::Round($c.Average); $row.ClockMin = $c.Minimum
        $row.MemClock = [math]::Round(($smiRows | ForEach-Object { [double]$_.mem } | Measure-Object -Average).Average)
        $row.PowerW = [math]::Round(($smiRows | ForEach-Object { [double]$_.power } | Measure-Object -Average).Average, 1)
        $row.TempC = [math]::Round(($smiRows | ForEach-Object { [double]$_.temp } | Measure-Object -Average).Average, 1)
        $row.Fan = [math]::Round(($smiRows | ForEach-Object { [double]$_.fan } | Measure-Object -Average).Average)
        $row.Reasons = ($smiRows | Group-Object reason | ForEach-Object { "$($_.Name.Trim() -replace '0x0+', '0x')=$($_.Count)" }) -join ' '
        $row.EffectiveMv = if ($step.Stock) { 'stock' } else { Get-EffectiveMv $row.ClockAvg ([int]$step.Core) }

        if (-not $firstFps) { $firstFps = $row.Fps }
        elseif ($row.Fps -lt $firstFps * 0.5) { throw "FPS collapsed to $($row.Fps)" }
    } catch {
        $row.Result = "FAIL: $($_.Exception.Message)"
    }
    $obj = [pscustomobject]$row
    $results.Add($obj)
    $obj | Export-Csv -Path $resultCsv -Append -NoTypeInformation
    Write-Host ("  -> fps {0} (1% {1})  clk {2}  {3} W  {4} C  ~{5} mV  {6}" -f $row.Fps, $row.Low1, $row.ClockAvg, $row.PowerW, $row.TempC, $row.EffectiveMv, $row.Result)

    if ($row.Result -ne 'ok') {
        Write-Warning "Step $name failed; applying safe settings and stopping."
        try { $null = Set-Step $SafeStep } catch { Write-Warning "Safe restore failed: $_" }
        break
    }
}

if ($RestoreSafe -and $results[-1].Result -eq 'ok') { $null = Set-Step $SafeStep }
"Results: $resultCsv"
$results | Format-Table Step, Core, TargetMv, MaxClock, Mem, Power, Xbar, XbarMhz, Fps, Low1, ClockAvg, ClockMin, PowerW, TempC, EffectiveMv, Result -AutoSize | Out-String -Width 250
