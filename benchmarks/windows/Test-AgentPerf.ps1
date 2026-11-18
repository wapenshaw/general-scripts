<#
.SYNOPSIS
    Compares CLI-agent friendly workloads on Windows (C:, D:) and WSL ext4.
.DESCRIPTION
    Micro: process-spawn cost per shell (pwsh, Git Bash, WSL bash) and the file/search/git
    operations coding agents issue constantly, against every target.
    Claude: runs the same read-only prompt through `claude -p --output-format json` on each
    target and reports total, API and local (total - API) time. Local time is the part the
    filesystem and shell can influence. Each Claude run bills tokens.
    Copilot: optional wall-clock-only timing of `copilot -p` (no API split is available).
.PARAMETER Mode
    Micro, Claude, Copilot or any combination.
.PARAMETER WindowsRoot
    Windows folders that contain the Astra repos.
.PARAMETER WslRoot
    Repo root inside the WSL distro. Empty skips WSL.
.PARAMETER Runs
    Timed runs per measurement.
.PARAMETER GitBash
    Also launch the Windows `claude` from Git Bash on the first Windows root.
.EXAMPLE
    ./Test-AgentPerf.ps1 -Mode Micro
.EXAMPLE
    ./Test-AgentPerf.ps1 -Mode Claude -Runs 3 -GitBash
#>
#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Micro', 'Claude', 'Copilot')]
    [string[]]$Mode = @('Micro'),
    [string[]]$WindowsRoot = @('D:\Astra', 'C:\Code\Astra'),
    [string]$WslRoot = '~/astra',
    [int]$Runs = 3,
    [switch]$GitBash
)
$ErrorActionPreference = 'Stop'
$gitBashExe = 'C:\Program Files\Git\bin\bash.exe'
$prompt = 'Use Grep to count the python files that contain the word import across this directory tree, then run git -C Shared-Library status --short and git -C Dns-API log --oneline -n 20 with Bash. Reply with one line: the count of python files.'
$repos = 'Administration-API', 'Astra-Automic', 'Astra-Infoblox', 'Astra-Library', 'Astra-Servicenow', 'Astra-SoftwareCatalog',
    'Common-Automation', 'Dns-API', 'Firewall-API', 'Hostmanagement-API', 'ITSM-API', 'Schedule-API', 'Shared-Config',
    'Shared-Library', 'Shared-Processor', 'SoftwareCatalog-API', 'Storage-API', 'Temporal-Worker'

function Get-Median([double[]]$v) { $s = $v | Sort-Object; $s[[int][math]::Floor(($s.Count - 1) / 2)] }

function Measure-Block([scriptblock]$Block, [int]$N = $Runs) {
    $t = foreach ($i in 0..$N) { (Measure-Command { & $Block | Out-Null }).TotalSeconds }
    Get-Median ($t | Select-Object -Skip 1)
}

function Measure-WslCmd([string]$Command, [int]$N = $Runs) {
    $w = 's=$(date +%s.%N); { ' + $Command + '; } >/dev/null 2>&1; e=$(date +%s.%N); echo "$e - $s" | bc -l'
    $t = foreach ($i in 0..$N) { [double](wsl.exe -e bash -lc $w | Select-Object -Last 1) }
    if ($N -eq 0) { return $t[0] }
    Get-Median ($t | Select-Object -Skip 1)
}

$rows = [System.Collections.Generic.List[object]]::new()
function Add-Row($Group, $Test, $Target, $Value) {
    $rows.Add([pscustomobject]@{ Group = $Group; Test = $Test; Target = $Target; Value = [math]::Round($Value, 3) })
}

if ('Micro' -in $Mode) {
    Write-Host '== spawn cost (100 x git --version)' -ForegroundColor Cyan
    Add-Row 'spawn' '100 x git --version' 'pwsh' (Measure-Block { 1..100 | ForEach-Object { git --version } } 2)
    if (Test-Path $gitBashExe) {
        $gb = '& ' + "'$gitBashExe'" + ' -c ''for i in $(seq 100); do git --version; done'''
        Add-Row 'spawn' '100 x git --version' 'git bash' (Measure-Block ([scriptblock]::Create($gb)) 2)
        Add-Row 'spawn' 'shell start (bash -c true)' 'git bash' (Measure-Block { & $gitBashExe -c true } 5)
    }
    Add-Row 'spawn' 'shell start (pwsh -NoProfile)' 'pwsh' (Measure-Block { pwsh -NoProfile -c 'exit' } 5)
    Add-Row 'spawn' 'shell start (pwsh + profile)' 'pwsh' (Measure-Block { pwsh -c 'exit' } 5)
    if ($WslRoot) {
        Add-Row 'spawn' '100 x git --version' 'wsl bash' (Measure-WslCmd 'for i in $(seq 100); do git --version; done' 2)
        Add-Row 'spawn' 'shell start (wsl bash -c true)' 'wsl bash' (Measure-Block { wsl.exe -e bash -c true } 5)
    }

    foreach ($root in $WindowsRoot) {
        if (-not (Test-Path -LiteralPath $root)) { Write-Warning "Skipping $root"; continue }
        $target = "win $(Split-Path $root -Qualifier)"
        Write-Host "== file ops on $root" -ForegroundColor Cyan
        Add-Row 'ops' 'rg count py files with import' $target (Measure-Block { rg -l --type py import $root })
        Add-Row 'ops' 'glob **/*.py' $target (Measure-Block { rg --files --glob '*.py' $root })
        Add-Row 'ops' 'git status x18 repos' $target (Measure-Block { foreach ($r in $repos) { git -C (Join-Path $root $r) status --porcelain } })
        $files = rg --files --glob '*.py' (Join-Path $root 'Shared-Library') | Select-Object -First 300
        Add-Row 'ops' 'read 300 files' $target (Measure-Block { foreach ($f in $files) { [IO.File]::ReadAllText($f) } })
        $scratch = Join-Path $root "Shared-Library\.agentperf-$PID"
        Add-Row 'ops' 'edit 100 files in place' $target (Measure-Block {
            New-Item -ItemType Directory -Path $scratch -Force | Out-Null
            1..100 | ForEach-Object { [IO.File]::WriteAllText("$scratch\f$_.txt", 'a') }
            1..100 | ForEach-Object { [IO.File]::AppendAllText("$scratch\f$_.txt", 'b') }
            Remove-Item -LiteralPath $scratch -Recurse -Force
        })
    }
    if ($WslRoot) {
        Write-Host "== file ops on wsl $WslRoot" -ForegroundColor Cyan
        $r = $WslRoot
        Add-Row 'ops' 'rg count py files with import' 'wsl ext4' (Measure-WslCmd "rg -l --type py import $r")
        Add-Row 'ops' 'glob **/*.py' 'wsl ext4' (Measure-WslCmd "rg --files --glob '*.py' $r")
        $loop = ($repos | ForEach-Object { "git -C $r/$_ status --porcelain" }) -join '; '
        Add-Row 'ops' 'git status x18 repos' 'wsl ext4' (Measure-WslCmd $loop)
        Add-Row 'ops' 'read 300 files' 'wsl ext4' (Measure-WslCmd "rg --files --glob '*.py' $r/Shared-Library | head -300 | xargs cat")
        $s = "$r/Shared-Library/.agentperf-$PID"
        Add-Row 'ops' 'edit 100 files in place' 'wsl ext4' (Measure-WslCmd "mkdir -p $s; for i in `$(seq 1 100); do printf a > $s/f`$i.txt; done; for i in `$(seq 1 100); do printf b >> $s/f`$i.txt; done; rm -rf $s")
    }
}

function Invoke-ClaudeRun([string]$Target, [scriptblock]$Launch) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $json = & $Launch
    $wall = $sw.Elapsed.TotalSeconds
    $o = ($json | Out-String) | ConvertFrom-Json
    # Some CLI builds emit an array of events instead of a single result object.
    if ($o -is [array]) { $o = $o | Where-Object type -eq 'result' | Select-Object -Last 1 }
    [pscustomobject]@{
        Target = $Target; Wall = $wall; Total = $o.duration_ms / 1000; Api = $o.duration_api_ms / 1000
        Local = ($o.duration_ms - $o.duration_api_ms) / 1000; Turns = $o.num_turns; Cost = [double]$o.total_cost_usd
    }
}

if ('Claude' -in $Mode) {
    $results = [System.Collections.Generic.List[object]]::new()
    $allowed = 'Glob,Grep,Read,Bash'
    $targets = [System.Collections.Generic.List[object]]::new()
    foreach ($root in $WindowsRoot) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $r = $root
        $targets.Add(@{ Name = "win $(Split-Path $r -Qualifier) (pwsh)"; Run = { Push-Location $r; try { claude -p $prompt --output-format json --allowedTools $allowed } finally { Pop-Location } }.GetNewClosure() })
    }
    if ($GitBash -and (Test-Path $gitBashExe) -and $WindowsRoot) {
        $unix = '/' + (($WindowsRoot[0] -replace '^([A-Za-z]):', '$1').ToLower() -replace '\\', '/')
        $targets.Add(@{ Name = "win $(Split-Path $WindowsRoot[0] -Qualifier) (git bash)"; Run = { & $gitBashExe -c "cd '$unix' && claude -p '$prompt' --output-format json --allowedTools $allowed" }.GetNewClosure() })
    }
    if ($WslRoot) {
        $targets.Add(@{ Name = 'wsl ext4'; Run = { wsl.exe -e bash -lc "cd $WslRoot && claude -p '$prompt' --output-format json --allowedTools $allowed < /dev/null" }.GetNewClosure() })
    }
    foreach ($t in $targets) {
        Write-Host "== claude -p on $($t.Name)" -ForegroundColor Cyan
        foreach ($i in 1..$Runs) { $results.Add((Invoke-ClaudeRun $t.Name $t.Run)) }
    }
    $results | Group-Object Target | ForEach-Object {
        [pscustomobject]@{
            Target = $_.Name
            'wall s' = [math]::Round((Get-Median $_.Group.Wall), 2)
            'total s' = [math]::Round((Get-Median $_.Group.Total), 2)
            'api s' = [math]::Round((Get-Median $_.Group.Api), 2)
            'local s' = [math]::Round((Get-Median $_.Group.Local), 2)
            turns = (Get-Median $_.Group.Turns)
            'cost $' = [math]::Round(($_.Group.Cost | Measure-Object -Sum).Sum, 2)
        }
    } | Format-Table -AutoSize
}

if ('Copilot' -in $Mode) {
    $copilotPrompt = 'Count the python files containing the word import across this directory tree using grep and reply with only the number.'
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($root in $WindowsRoot) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Write-Host "== copilot -p on $root" -ForegroundColor Cyan
        foreach ($i in 1..$Runs) {
            Push-Location $root
            try { $s = (Measure-Command { copilot -p $copilotPrompt --allow-all-tools | Out-Null }).TotalSeconds } finally { Pop-Location }
            $results.Add([pscustomobject]@{ Target = "win $(Split-Path $root -Qualifier)"; Wall = $s })
        }
    }
    if ($WslRoot) {
        Write-Host '== copilot -p on wsl' -ForegroundColor Cyan
        foreach ($i in 1..$Runs) {
            $s = Measure-WslCmd "cd $WslRoot && copilot -p '$copilotPrompt' --allow-all-tools" 0
            $results.Add([pscustomobject]@{ Target = 'wsl ext4'; Wall = $s })
        }
    }
    $results | Group-Object Target | ForEach-Object {
        [pscustomobject]@{ Target = $_.Name; 'wall s (median)' = [math]::Round((Get-Median $_.Group.Wall), 2) }
    } | Format-Table -AutoSize
}

if ($rows.Count) {
    $columns = $rows.Target | Select-Object -Unique
    $rows | Group-Object Group, Test | ForEach-Object {
        $row = [ordered]@{ Test = $_.Group[0].Test }
        foreach ($c in $columns) { $row[$c] = ($_.Group | Where-Object Target -eq $c | Select-Object -First 1).Value }
        [pscustomobject]$row
    } | Format-Table -AutoSize
}
