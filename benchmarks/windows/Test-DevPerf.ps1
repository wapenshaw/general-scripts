<#
.SYNOPSIS
    Benchmarks git, search and small-file I/O across Windows volumes and WSL ext4.
.DESCRIPTION
    Runs the same operations against the same repo on each target and prints median
    seconds per operation. Windows targets run natively; the WSL target runs inside
    the distro so wsl.exe start-up time is excluded.
.PARAMETER Repo
    Repo folder name present under every target root.
.PARAMETER WindowsRoot
    Windows folders containing the repo, e.g. C:\Code\Astra and D:\Astra.
.PARAMETER WslRoot
    Path inside the WSL distro that contains the repo. Empty skips WSL.
.PARAMETER Runs
    Timed runs per operation (a warm-up run is always discarded).
.PARAMETER FileCount
    Number of small files created and deleted by the file I/O test.
.PARAMETER UvProject
    Optional repo folder name with a uv.lock; adds a clean-venv `uv sync` test.
.EXAMPLE
    ./Test-DevPerf.ps1 -Repo Common-Automation -WindowsRoot C:\Code\Astra,D:\Astra -WslRoot '~/astra'
#>
#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Repo = 'Common-Automation',
    [string[]]$WindowsRoot = @('C:\Code\Astra', 'D:\Astra'),
    [string]$WslRoot = '~/astra',
    [int]$Runs = 5,
    [int]$FileCount = 2000,
    [string]$UvProject
)
$ErrorActionPreference = 'Stop'

function Get-Median([double[]]$Values) {
    $s = $Values | Sort-Object
    $s[[int][math]::Floor(($s.Count - 1) / 2)]
}

function Measure-Windows([scriptblock]$Block) {
    $times = foreach ($i in 0..$Runs) {
        (Measure-Command { & $Block | Out-Null }).TotalSeconds
    }
    Get-Median ($times | Select-Object -Skip 1)
}

function Measure-Wsl([string]$Command) {
    $wrapped = 's=$(date +%s.%N); { ' + $Command + '; } >/dev/null 2>&1; e=$(date +%s.%N); echo "$e - $s" | bc -l'
    $times = foreach ($i in 0..$Runs) {
        [double](wsl.exe -e bash -lc $wrapped | Select-Object -Last 1)
    }
    Get-Median ($times | Select-Object -Skip 1)
}

$tests = [ordered]@{
    'git status'         = @{
        Win = { param($r) git -C $r status --porcelain }
        Wsl = { param($r) "git -C $r/$Repo status --porcelain" }
    }
    'git rev-list'       = @{
        Win = { param($r) git -C $r rev-list --count --all }
        Wsl = { param($r) "git -C $r/$Repo rev-list --count --all" }
    }
    'git grep'           = @{
        Win = { param($r) git -C $r grep -n -I 'import' }
        Wsl = { param($r) "git -C $r/$Repo grep -n -I import" }
    }
    'file walk'          = @{
        Win = { param($r) Get-ChildItem -LiteralPath $r -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Length } | Measure-Object -Sum }
        Wsl = { param($r) "find $r/$Repo -type f -printf '%s\n' | awk '{s+=\$1} END {print s}'" }
    }
}

$results = [System.Collections.Generic.List[object]]::new()
$add = {
    param($Target, $Test, $Seconds)
    $results.Add([pscustomobject]@{ Target = $Target; Test = $Test; Seconds = [math]::Round($Seconds, 3) })
}

foreach ($root in $WindowsRoot) {
    $repoPath = Join-Path $root $Repo
    if (-not (Test-Path -LiteralPath $repoPath)) { Write-Warning "Skipping $repoPath (missing)"; continue }
    $target = "win $((Split-Path $root -Qualifier))"
    Write-Host "== $target ($repoPath)" -ForegroundColor Cyan
    foreach ($name in $tests.Keys) {
        $win = $tests[$name].Win
        & $add $target $name (Measure-Windows { & $win $repoPath })
    }
    $scratch = Join-Path $root ".devperf-$PID"
    & $add $target "create+delete $FileCount files" (Measure-Windows {
        New-Item -ItemType Directory -Path $scratch -Force | Out-Null
        1..$FileCount | ForEach-Object { [IO.File]::WriteAllText("$scratch\f$_.txt", 'x') }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    })
    if ($UvProject -and (Get-Command uv -ErrorAction SilentlyContinue)) {
        $venv = Join-Path $root ".devperf-venv-$PID"
        $env:UV_PROJECT_ENVIRONMENT = $venv
        & uv sync --frozen --project (Join-Path $root $UvProject) *> $null
        & $add $target 'uv sync (clean venv, warm cache)' (Measure-Windows {
            Remove-Item -LiteralPath $venv -Recurse -Force -ErrorAction SilentlyContinue
            uv sync --frozen --project (Join-Path $root $UvProject) *> $null
        })
        Remove-Item -LiteralPath $venv -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\UV_PROJECT_ENVIRONMENT
    }
}

if ($WslRoot) {
    Write-Host "== wsl ($WslRoot)" -ForegroundColor Cyan
    foreach ($name in $tests.Keys) {
        & $add 'wsl ext4' $name (Measure-Wsl (& $tests[$name].Wsl $WslRoot))
    }
    $wscratch = "$WslRoot/.devperf-$PID"
    & $add 'wsl ext4' "create+delete $FileCount files" (Measure-Wsl "mkdir -p $wscratch && for i in `$(seq 1 $FileCount); do printf x > $wscratch/f`$i.txt; done; rm -rf $wscratch")
    if ($UvProject) {
        $venv = "$WslRoot/.devperf-venv-$PID"
        $cmd = "UV_PROJECT_ENVIRONMENT=$venv uv sync --frozen --project $WslRoot/$UvProject"
        wsl.exe -e bash -lc "$cmd" *> $null
        & $add 'wsl ext4' 'uv sync (clean venv, warm cache)' (Measure-Wsl "rm -rf $venv; $cmd")
        wsl.exe -e bash -lc "rm -rf $venv" | Out-Null
    }
}

$results | Group-Object Test | ForEach-Object {
    $row = [ordered]@{ Test = $_.Name }
    foreach ($r in $_.Group) { $row[$r.Target] = $r.Seconds }
    [pscustomobject]$row
} | Format-Table -AutoSize
