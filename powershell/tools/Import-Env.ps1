<#
.SYNOPSIS
    Restores Windows environment variables from the JSON files written by Export-Env.ps1.

.DESCRIPTION
    Reads user.json (and, with -IncludeMachine, system.json) from <repo>\config\env\ and
    applies every variable via [Environment]::SetEnvironmentVariable. By default each
    variable is set verbatim, clobbering whatever is on the target system. Use -MergePath
    to preserve the existing Path and append the captured entries (deduped).

.PARAMETER ConfigDir
    Directory containing user.json / system.json. Defaults to <repo>\config\env.
.PARAMETER IncludeMachine
    Also apply machine-scope vars from system.json. Requires an elevated PowerShell session.
.PARAMETER MergePath
    Preserve the target system's existing Path entries and append the captured ones
    (deduped) instead of replacing the whole Path.
.PARAMETER DryRun
    Print what would be set without writing to the registry.

.EXAMPLE
    PS> pwsh -File .\Import-Env.ps1
    PS> pwsh -File .\Import-Env.ps1 -IncludeMachine
    PS> pwsh -File .\Import-Env.ps1 -IncludeMachine -DryRun
    PS> pwsh -File .\Import-Env.ps1 -MergePath

.NOTES
    Pair with Export-Env.ps1. See config\env\README.md for what is filtered out and
    portability caveats (drive letters, WinGet subdir names).
#>

[CmdletBinding()]
param(
    [string]$ConfigDir = (Join-Path $PSScriptRoot "..\..\config\env"),
    [switch]$IncludeMachine,
    [switch]$MergePath,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Apply-Env {
    param(
        [Parameter(Mandatory)] [string]$JsonPath,
        [Parameter(Mandatory)] [string]$Scope
    )

    if (-not (Test-Path $JsonPath)) {
        Write-Warning "Skip (missing): $JsonPath"
        return
    }

    $data = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json
    if (-not $data.vars) {
        Write-Warning "Skip (no vars): $JsonPath"
        return
    }

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    if ($Scope -eq 'Machine' -and -not $isAdmin) {
        Write-Warning "Skipping $Scope (requires admin)"
        return
    }

    Write-Host "[*] Applying $($data.vars.PSObject.Properties.Count) vars from $JsonPath -> $Scope" -ForegroundColor Yellow

    $sortedNames = $data.vars.PSObject.Properties.Name | Sort-Object
    foreach ($name in $sortedNames) {
        $entry = $data.vars.$name
        $value = [string]$entry.value
        $kind  = $entry.type

        if ($name -ieq 'Path' -and $MergePath) {
            $existing = [Environment]::GetEnvironmentVariable('Path', $Scope)
            $existingParts = if ($existing) { $existing -split ';' | Where-Object { $_ } } else { @() }
            $newParts      = $value -split ';' | Where-Object { $_ }
            $combined      = @($existingParts + $newParts) | Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() } | Select-Object -Unique
            $value = $combined -join ';'
        }

        if ($DryRun) {
            Write-Host ("  [DRY] {0} :: {1} = {2}" -f $Scope, $name, $value) -ForegroundColor DarkGray
        } else {
            [Environment]::SetEnvironmentVariable($name, $value, $Scope)
            Write-Host ("  [set] {0} :: {1}" -f $Scope, $name) -ForegroundColor Green
        }
    }

    if ($data.filtered -and $data.filtered.Count -gt 0) {
        Write-Host ("  [*] {0} filtered on export (not restored):" -f $data.filtered.Count) -ForegroundColor DarkYellow
        $data.filtered | ForEach-Object { Write-Host ("      - {0}  ({1})" -f $_.name, $_.reason) -ForegroundColor DarkYellow }
    }
}

Apply-Env -JsonPath (Join-Path $ConfigDir 'user.json')   -Scope 'User'
if ($IncludeMachine) {
    Apply-Env -JsonPath (Join-Path $ConfigDir 'system.json') -Scope 'Machine'
}
