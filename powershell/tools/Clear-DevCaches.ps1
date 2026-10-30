<#
.SYNOPSIS
    Clears regenerable temp files and developer caches, reporting the space recovered.

.DESCRIPTION
    Each target is something its owner rebuilds or re-downloads on demand:

      Temp        files in %TEMP% older than -TempAgeDays (in-use files are skipped)
      CrashDumps  %LOCALAPPDATA%\CrashDumps
      Teams       new Teams LocalCache (skipped while Teams is running)
      uv          `uv cache prune` (unused entries only)
      pip         `pip cache purge`
      npm         `npm cache clean --force`
      Cargo       downloaded crates and extracted sources (the registry index is kept)
      Docker      `docker system prune -f` (opt-in; removes stopped containers,
                  unused networks, dangling images and build cache)

    Missing tools and folders are skipped. Supports -WhatIf, which only reports sizes.

.PARAMETER Targets
    Targets to clear. Default: everything except Docker.
.PARAMETER TempAgeDays
    Only delete temp files last written more than this many days ago. Default: 7.

.EXAMPLE
    PS> pwsh -File .\Clear-DevCaches.ps1 -WhatIf
    PS> pwsh -File .\Clear-DevCaches.ps1
    PS> .\Clear-DevCaches.ps1 -Targets Temp,CrashDumps,Docker
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Temp', 'CrashDumps', 'Teams', 'uv', 'pip', 'npm', 'Cargo', 'Docker')]
    [string[]]$Targets = @('Temp', 'CrashDumps', 'Teams', 'uv', 'pip', 'npm', 'Cargo'),
    [ValidateRange(0, 3650)]
    [int]$TempAgeDays = 7
)

function Get-FolderBytes([string[]]$Paths) {
    $total = 0
    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path) {
            $total += (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        }
    }
    [long]$total
}

function Format-Size([long]$Bytes) {
    if ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) } else { '{0:N0} MB' -f ($Bytes / 1MB) }
}

function Remove-FolderContent([string[]]$Paths, [datetime]$OlderThan = [datetime]::MaxValue) {
    $failed = 0
    foreach ($path in $Paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object LastWriteTime -lt $OlderThan |
            ForEach-Object {
                try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { $failed++ }
            }
        # Remove directories left empty, deepest first.
        Get-ChildItem -LiteralPath $path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) } |
            ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
    }
    $failed
}

$cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $HOME '.cargo' }
$folders = @{
    Temp       = @($env:TEMP)
    CrashDumps = @(Join-Path $env:LOCALAPPDATA 'CrashDumps')
    Teams      = @(Join-Path $env:LOCALAPPDATA 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache')
    Cargo      = @((Join-Path $cargoHome 'registry\cache'), (Join-Path $cargoHome 'registry\src'))
}
$commands = @{
    uv     = @{ Exe = 'uv'; Args = @('cache', 'prune'); Dir = { uv cache dir 2>$null } }
    pip    = @{ Exe = 'pip'; Args = @('cache', 'purge'); Dir = { pip cache dir 2>$null } }
    npm    = @{ Exe = 'npm'; Args = @('cache', 'clean', '--force'); Dir = { Join-Path (npm config get cache 2>$null) '_cacache' } }
    Docker = @{ Exe = 'docker'; Args = @('system', 'prune', '-f'); Dir = $null }
}

$results = foreach ($target in $Targets) {
    $status = 'Cleared'
    $before = 0L
    $after = 0L

    if ($folders.ContainsKey($target)) {
        $paths = $folders[$target]
        $before = Get-FolderBytes $paths
        if ($before -eq 0) {
            $status = 'Nothing to clear'
        }
        elseif ($target -eq 'Teams' -and (Get-Process -Name 'ms-teams' -ErrorAction SilentlyContinue)) {
            $status = 'Skipped: quit Teams first'
        }
        elseif ($PSCmdlet.ShouldProcess(($paths -join ', '), "Clear $target")) {
            $cutoff = if ($target -eq 'Temp') { (Get-Date).AddDays(-$TempAgeDays) } else { [datetime]::MaxValue }
            $failed = Remove-FolderContent $paths $cutoff
            if ($failed) { $status = "Cleared ($failed in use)" }
        }
        else {
            $status = 'WhatIf'
        }
        $after = if ($status -eq 'Cleared' -or $status -like 'Cleared (*') { Get-FolderBytes $paths } else { $before }
    }
    else {
        $command = $commands[$target]
        if (-not (Get-Command $command.Exe -ErrorAction SilentlyContinue)) {
            $status = 'Skipped: not installed'
        }
        else {
            $dir = if ($command.Dir) { & $command.Dir }
            if ($dir) { $before = Get-FolderBytes @($dir) }
            if ($PSCmdlet.ShouldProcess("$($command.Exe) $($command.Args -join ' ')", "Clear $target")) {
                & $command.Exe @($command.Args) | Out-Host
                if ($LASTEXITCODE -ne 0) { $status = "Failed (exit $LASTEXITCODE)" }
                $after = if ($dir) { Get-FolderBytes @($dir) } else { 0L }
            }
            else {
                $status = 'WhatIf'
                $after = $before
            }
        }
    }

    [pscustomobject]@{
        Target = $target
        Before = Format-Size $before
        Freed  = Format-Size ([math]::Max(0, $before - $after))
        Status = $status
        Bytes  = [math]::Max(0, $before - $after)
    }
}

$results | Format-Table Target, Before, Freed, Status -AutoSize
Write-Host ("Total freed: {0}" -f (Format-Size ($results | Measure-Object Bytes -Sum).Sum)) -ForegroundColor Green
