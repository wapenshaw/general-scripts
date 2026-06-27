<#
.SYNOPSIS
    Exports the current Windows environment variables (user and/or machine scope) to JSON.

.DESCRIPTION
    Reads from HKCU:\Environment and (when -IncludeMachine is set and the shell is elevated)
    from HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment. Writes the result
    to user.json and/or system.json in the repo's config\env\ folder.

    Secrets, session vars, and process vars are filtered out (see the $Filter block to change).
    The list of stripped variables is recorded in the JSON's "filtered" array.

.PARAMETER OutputDir
    Directory to write the JSON files into. Defaults to <repo>\config\env.
.PARAMETER IncludeMachine
    Also export machine-scope env vars. Requires an elevated PowerShell session.

.EXAMPLE
    PS> pwsh -File .\Export-Env.ps1
    PS> pwsh -File .\Export-Env.ps1 -IncludeMachine

.NOTES
    Run the -IncludeMachine variant once on the source machine, then commit the resulting
    user.json and system.json alongside this script. Use Import-Env.ps1 to restore on a
    fresh system.
#>

[CmdletBinding()]
param(
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\config\env"),
    [switch]$IncludeMachine
)

$ErrorActionPreference = "Stop"

$Filter = @(
    @{ Pattern = '*AUTH_COOKIE*';          Reason = 'secret' }
    @{ Pattern = '*_AUTH*';                Reason = 'secret' }
    @{ Pattern = '*TOKEN*';                Reason = 'secret' }
    @{ Pattern = '*SECRET*';               Reason = 'secret' }
    @{ Pattern = '*PASSWORD*';             Reason = 'secret' }
    @{ Pattern = '*PASSWD*';               Reason = 'secret' }
    @{ Pattern = '*APIKEY*';               Reason = 'secret' }
    @{ Pattern = '*API_KEY*';              Reason = 'secret' }
    @{ Pattern = '*PRIVATE_KEY*';          Reason = 'secret' }
    @{ Pattern = 'STARSHIP_SESSION_KEY';   Reason = 'session' }
    @{ Pattern = 'STARSHIP_SHELL';         Reason = 'session' }
    @{ Pattern = 'WT_SESSION';             Reason = 'session' }
    @{ Pattern = 'WT_PROFILE_ID';          Reason = 'session' }
    @{ Pattern = 'OPENCODE_*_WORKSPACE_ID';Reason = 'session' }
    @{ Pattern = 'OPENCODE_*_AUTH*';       Reason = 'secret' }
    @{ Pattern = 'npm_config_user_agent';  Reason = 'runtime' }
    @{ Pattern = 'PROCESSOR_*';            Reason = 'process' }
    @{ Pattern = 'NUMBER_OF_PROCESSORS';   Reason = 'process' }
    @{ Pattern = 'LOGONSERVER';            Reason = 'session' }
    @{ Pattern = 'SESSIONNAME';            Reason = 'session' }
)

function Get-FilterReason {
    param([string]$Name)
    foreach ($f in $Filter) {
        if ($Name -like $f.Pattern) { return $f.Reason }
    }
    return $null
}

function Export-EnvScope {
    param(
        [Parameter(Mandatory)] [string]$Scope,
        [Parameter(Mandatory)] [string]$RegistryKey
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
    if ($Scope -eq 'Machine' -and -not $isAdmin) {
        Write-Warning "Skipping $Scope scope (requires admin): $RegistryKey"
        return $null
    }

    if (-not (Test-Path $RegistryKey)) {
        Write-Warning "Registry key not found: $RegistryKey"
        return $null
    }

    $key = Get-Item -LiteralPath $RegistryKey
    $names = $key.GetValueNames()

    $vars = [ordered]@{}
    $filtered = New-Object System.Collections.Generic.List[object]

    foreach ($name in ($names | Sort-Object)) {
        $reason = Get-FilterReason $name
        if ($reason) {
            $filtered.Add([PSCustomObject]@{ name = $name; reason = $reason }) | Out-Null
            continue
        }
        $value = $key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind  = $key.GetValueKind($name).ToString()

        $type = switch ($kind) {
            'ExpandString' { 'REG_EXPAND_SZ' }
            'String'       { 'REG_SZ' }
            'DWord'        { 'REG_DWORD' }
            'QWord'        { 'REG_QWORD' }
            'MultiString'  { 'REG_MULTI_SZ' }
            default        { $kind }
        }

        $storedValue = if ($type -in 'REG_DWORD', 'REG_QWORD') { [int64]$value } else { [string]$value }
        $vars[$name] = [ordered]@{ value = $storedValue; type = $type }
    }

    return [PSCustomObject]@{
        schemaVersion = 1
        capturedAt    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        host          = $env:COMPUTERNAME
        scope         = $Scope
        varCount      = $vars.Count
        filteredCount = $filtered.Count
        vars          = $vars
        filtered      = $filtered
    }
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "[+] Created $OutputDir" -ForegroundColor Cyan
}

$userData = Export-EnvScope -Scope 'User' -RegistryKey 'HKCU:\Environment'
if ($userData) {
    $userPath = Join-Path $OutputDir 'user.json'
    $userData | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $userPath -Encoding utf8NoBOM
    Write-Host "[+] Wrote user env: $userPath ($($userData.varCount) vars, $($userData.filteredCount) filtered)" -ForegroundColor Green
}

if ($IncludeMachine) {
    $sysData = Export-EnvScope -Scope 'Machine' -RegistryKey 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
    if ($sysData) {
        $sysPath = Join-Path $OutputDir 'system.json'
        $sysData | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $sysPath -Encoding utf8NoBOM
        Write-Host "[+] Wrote system env: $sysPath ($($sysData.varCount) vars, $($sysData.filteredCount) filtered)" -ForegroundColor Green
    }
} else {
    Write-Host "[*] Re-run with -IncludeMachine in an admin shell to also export system env vars" -ForegroundColor Yellow
}
