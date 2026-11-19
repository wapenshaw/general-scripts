<#
.SYNOPSIS
    Cuts per-call startup cost for git, rg and claude: real git first on PATH,
    plus Defender process exclusions.

.DESCRIPTION
    Coding agents start git and rg hundreds of times per session, so each call's
    startup time matters more than disk speed (benchmarks/bench.py micro shows this).
    Two fixes:

      1. Machine PATH: puts Git for Windows' real git folder (ucrt64\bin,
         mingw64\bin or clangarm64\bin) directly before Git\cmd. Git\cmd\git.exe
         is a launcher that starts the real git.exe, so every call creates two
         processes. Git\cmd sits in the Machine PATH, which Windows places before
         the User PATH, so this edit needs admin. Side effect: curl.exe, git-lfs.exe
         and scalar.exe from that folder now come before other copies on PATH,
         including C:\Windows\System32\curl.exe.
      2. Defender process exclusions for both git.exe files, Git Bash's bash.exe,
         rg.exe and claude.exe. Files those processes open are no longer
         scanned in real time. A winget-installed rg gets a wildcard on its
         versioned folder so the exclusion still matches after rg updates.

    The Machine PATH is read and written as REG_EXPAND_SZ without expansion, so
    %SystemRoot%-style entries survive, and the old value is saved to
    %USERPROFILE%\machine-path-backup-<timestamp>.txt first. Idempotent.

    Measured on TITAN (2026-11-18), git --version from pwsh: 52.6 ms through
    Git\cmd vs 30.4 ms direct; bench.py git status x18 repos 0.74 s -> 0.54 s.

.PARAMETER SkipPath
    Leave the Machine PATH alone; only add Defender exclusions.

.PARAMETER SkipDefender
    Leave Defender alone; only reorder the Machine PATH.

.PARAMETER ExtraProcess
    More full process paths (wildcards allowed) to exclude from Defender.

.EXAMPLE
    PS> pwsh -File .\powershell\system\Optimize-DevToolStartup.ps1 -WhatIf

.EXAMPLE
    PS> pwsh -File .\powershell\system\Optimize-DevToolStartup.ps1 -ExtraProcess 'C:\Users\me\.local\bin\uv.exe'

.NOTES
    Run elevated. Open a new terminal (fully restart Windows Terminal) afterwards.
    Undo: restore the Machine PATH from the backup file, and run
    Remove-MpPreference -ExclusionProcess <path> for each exclusion.
#>
#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipPath,
    [switch]$SkipDefender,
    [string[]]$ExtraProcess = @()
)

$ErrorActionPreference = 'Stop'

# Git for Windows install root, from its registry key or from git on PATH.
$gitRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\GitForWindows' -ErrorAction SilentlyContinue).InstallPath
if (-not $gitRoot) {
    $onPath = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) { $gitRoot = Split-Path (Split-Path $onPath.Source -Parent) -Parent }
}
if (-not $gitRoot -or -not (Test-Path -LiteralPath $gitRoot)) { throw 'Git for Windows not found' }

$gitCmd = Join-Path $gitRoot 'cmd'
$gitReal = 'ucrt64', 'mingw64', 'clangarm64' |
    ForEach-Object { Join-Path (Join-Path $gitRoot $_) 'bin' } |
    Where-Object { Test-Path -LiteralPath (Join-Path $_ 'git.exe') } |
    Select-Object -First 1
if (-not $gitReal) { throw "No real git.exe under $gitRoot\{ucrt64,mingw64,clangarm64}\bin" }

if (-not $SkipPath) {
    $key = Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    $raw = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $entries = [string[]]($raw -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ne $gitReal })
    $idx = [array]::FindIndex($entries, [Predicate[string]] { param($e) $e.TrimEnd('\') -eq $gitCmd })

    if ($idx -lt 0) {
        Write-Warning "$gitCmd is not in the Machine PATH; leaving PATH alone"
    } else {
        $before = if ($idx -gt 0) { @($entries[0..($idx - 1)]) } else { @() }
        $new = ($before + $gitReal + @($entries[$idx..($entries.Count - 1)])) -join ';'
        $current = ($raw -split ';' | Where-Object { $_ }) -join ';'

        if ($new -eq $current) {
            Write-Host "Machine PATH already has $gitReal before $gitCmd" -ForegroundColor DarkGray
        } elseif ($PSCmdlet.ShouldProcess('Machine PATH', "Insert $gitReal before $gitCmd")) {
            $backup = Join-Path $env:USERPROFILE "machine-path-backup-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
            $raw | Set-Content -LiteralPath $backup
            Set-ItemProperty -Path $key.PSPath -Name Path -Value $new -Type ExpandString
            Write-Host "Machine PATH: $gitReal now before $gitCmd (backup: $backup)" -ForegroundColor Green

            # Tell running apps (Explorer, new terminals) that the environment changed.
            Add-Type -Namespace Win32 -Name Env -MemberDefinition '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern IntPtr SendMessageTimeout(IntPtr h, uint m, UIntPtr w, string l, uint f, uint t, out UIntPtr r);'
            $r = [UIntPtr]::Zero
            [void][Win32.Env]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$r)
        }
    }
}

if (-not $SkipDefender) {
    # pwsh 7 loads ConfigDefender through the Windows PowerShell compatibility
    # proxy, whose file copies -WhatIf would otherwise skip, breaking the import.
    $savedWhatIf = $WhatIfPreference
    $WhatIfPreference = $false
    Import-Module ConfigDefender -WarningAction SilentlyContinue
    $WhatIfPreference = $savedWhatIf

    $procs = [System.Collections.Generic.List[string]]::new()
    $procs.Add((Join-Path $gitReal 'git.exe'))
    $procs.Add((Join-Path $gitCmd 'git.exe'))
    $bash = Join-Path $gitRoot 'usr\bin\bash.exe'
    if (Test-Path -LiteralPath $bash) { $procs.Add($bash) }

    $rg = Get-Command rg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($rg) {
        # winget keeps rg in a versioned folder (ripgrep-15.2.0-...); match any version.
        $procs.Add(($rg.Source -replace '\\ripgrep-[^\\]+\\rg\.exe$', '\*\rg.exe'))
    } else {
        Write-Warning 'rg not found on PATH; skipping its exclusion'
    }

    $claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $claude) { $procs.Add($claude) } else { Write-Warning "claude not found at $claude" }

    $ExtraProcess | ForEach-Object { $procs.Add($_) }

    $existing = @((Get-MpPreference).ExclusionProcess)
    $missing = @($procs | Where-Object { $_ -notin $existing } | Select-Object -Unique)

    if (-not $missing) {
        Write-Host 'Defender process exclusions already present' -ForegroundColor DarkGray
    } elseif ($PSCmdlet.ShouldProcess(($missing -join ', '), 'Add Defender process exclusion')) {
        Add-MpPreference -ExclusionProcess $missing
        Write-Host "Defender process exclusions added: $($missing -join ', ')" -ForegroundColor Green
    }
}

Write-Host 'Open a new terminal (fully restart Windows Terminal) to pick up the PATH.' -ForegroundColor Cyan
