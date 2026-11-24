<#
.SYNOPSIS
    Opens several repositories in one Zed window (multi-root workspace).

.DESCRIPTION
    Defines Open-ZedProject (alias: zp). Zed has no workspace file, so this resolves repo
    names under a root folder (default D:\Astra) and passes them to `zed` together, which
    opens them as one project, in the order given. With no arguments it opens the "all"
    list from a JSON file outside the repo (default D:\Zed-Setup\zed-groups.json):
    { "all": ["Storage-API", "Dns-API"] }.
    Without -Add the paths open in a new window; with -Add they join the current window.

.PARAMETER Name
    Repo folder names under -Root, or full paths.

.PARAMETER Group
    One or more group names from the group file.

.PARAMETER Root
    Folder that holds the repos. Default D:\Astra.

.PARAMETER GroupFile
    JSON file mapping group names to repo name arrays.

.PARAMETER Add
    Add the folders to the currently open Zed workspace instead of a new window.

.EXAMPLE
    PS> zp Dns-API Firewall-API

.EXAMPLE
    PS> zp -Group fastapi -WhatIf
#>

function Open-ZedProject {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Name,
        [string[]]$Group,
        [string]$Root = 'D:\Astra',
        [string]$GroupFile = 'D:\Zed-Setup\zed-groups.json',
        [switch]$Add
    )

    if (-not (Get-Command zed -ErrorAction SilentlyContinue)) {
        Write-Host "zed is not on PATH. Install Zed or add its bin folder to PATH." -ForegroundColor Red
        return
    }

    if (-not $Name -and -not $Group) { $Group = 'all' }

    $names = [System.Collections.Generic.List[string]]::new()
    if ($Name) { $names.AddRange($Name) }

    if ($Group) {
        if (-not (Test-Path -LiteralPath $GroupFile)) {
            Write-Host "Group file not found: $GroupFile" -ForegroundColor Red
            return
        }
        $groups = Get-Content -LiteralPath $GroupFile -Raw | ConvertFrom-Json
        foreach ($g in $Group) {
            $members = $groups.$g
            if (-not $members) {
                Write-Host "Unknown group '$g'. Available: $(($groups.PSObject.Properties.Name) -join ', ')" -ForegroundColor Red
                return
            }
            $names.AddRange([string[]]$members)
        }
    }

    if ($names.Count -eq 0) {
        Write-Host "Give repo names or -Group. Example: zp Dns-API Firewall-API" -ForegroundColor Yellow
        return
    }

    $paths = foreach ($n in ($names | Select-Object -Unique)) {
        $p = if (Test-Path -LiteralPath $n) { (Resolve-Path -LiteralPath $n).Path } else { Join-Path $Root $n }
        if (Test-Path -LiteralPath $p -PathType Container) { $p }
        else { Write-Host "Skipping '$n': $p not found." -ForegroundColor Yellow }
    }
    if (-not $paths) { return }

    $flag = if ($Add) { '--add' } else { '--new' }
    if ($PSCmdlet.ShouldProcess(($paths -join ', '), "zed $flag")) {
        & zed $flag @paths
    }
}

Set-Alias -Name zp -Value Open-ZedProject -Scope Global -Force
