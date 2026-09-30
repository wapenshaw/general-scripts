<#
.SYNOPSIS
    Applies the development storage manifest to User environment and tool config.
.DESCRIPTION
    Preserves existing package data, backs up changed registry values/config files,
    and supports -WhatIf. Does not pin interpreter directories into PATH. Optional
    cleanup removes known legacy PATH settings and matching Machine duplicates.
.PARAMETER Root
    Override the root in config/env/development.json.
.PARAMETER JavaHome
    Explicitly set User JAVA_HOME to an installed JDK. Omission preserves intentional
    User overrides, even when the java executable on Machine PATH uses another JDK.
.PARAMETER CleanPath
    Remove persisted VS developer-shell paths, obsolete pyenv entries and empty
    entries from User PATH. Runtime installations and unrelated paths are retained.
.PARAMETER RemoveMachineDuplicates
    Admin-only: remove Machine variables only when equal to the managed User value,
    and remove missing nvm directories from Machine PATH.
.EXAMPLE
    ./Set-DevPackagePaths.ps1 -CleanPath -WhatIf
.EXAMPLE
    ./Set-DevPackagePaths.ps1 -CleanPath
#>
#requires -Version 7.0
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../../config/env/development.json'),
    [string]$Root,
    [string]$JavaHome,
    [switch]$CleanPath,
    [switch]$RemoveMachineDuplicates
)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ($config.schemaVersion -ne 1) { throw 'Unsupported development manifest version.' }
if (-not $Root) { $Root = $config.root }
$Root = [IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath ([IO.Path]::GetPathRoot($Root)))) { throw "Drive unavailable: $Root" }
if ($JavaHome) {
    $JavaHome = [IO.Path]::GetFullPath($JavaHome).TrimEnd('\')
    if (-not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe'))) { throw "JDK not found: $JavaHome" }
}
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($RemoveMachineDuplicates -and -not $admin) { throw '-RemoveMachineDuplicates requires an elevated PowerShell.' }
$backupDir = Join-Path $env:LOCALAPPDATA ('PowerShellSetup/environment-backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + "-$PID")
$script:EnvBackup = [Collections.Generic.List[object]]::new()
function Save-PreviousVariable {
    param([string]$Name, [string]$Scope)
    $registryPath = if ($Scope -eq 'User') { 'HKCU:\Environment' } else { 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' }
    $key = Get-Item -LiteralPath $registryPath
    $exists = $key.GetValueNames() -contains $Name
    $script:EnvBackup.Add(@{
        name = $Name; scope = $Scope; exists = $exists
        value = if ($exists) { $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { $null }
        kind = if ($exists) { $key.GetValueKind($Name).ToString() } else { 'String' }
    })
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    ConvertTo-Json -InputObject @($script:EnvBackup.ToArray()) -Depth 5 | Set-Content -LiteralPath (Join-Path $backupDir 'environment.json')
}
function Set-ManagedVariable {
    param([string]$Name, [AllowNull()][string]$Value, [string]$Scope = 'User')
    $previous = [Environment]::GetEnvironmentVariable($Name, $Scope)
    $registryPath = if ($Scope -eq 'User') { 'HKCU:\Environment' } else { 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' }
    $exists = (Get-Item -LiteralPath $registryPath).GetValueNames() -contains $Name
    if ((-not [string]::IsNullOrEmpty($Value) -and $previous -ceq $Value) -or
        ([string]::IsNullOrEmpty($Value) -and -not $exists)) { return }
    if ($PSCmdlet.ShouldProcess("$Scope $Name", "Set to '$Value'")) {
        Save-PreviousVariable $Name $Scope
        if ([string]::IsNullOrEmpty($Value)) {
            Remove-ItemProperty -LiteralPath $registryPath -Name $Name -ErrorAction Stop
            if ($Scope -eq 'User') { Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue }
        } else {
            [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
            if ($Scope -eq 'User' -and $Name -ne 'Path') { [Environment]::SetEnvironmentVariable($Name, $Value, 'Process') }
        }
    }
}
function Write-ManagedFile {
    param([string]$Path, [string]$Content)
    $old = if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw } else { '' }
    if ($old.TrimEnd() -ceq $Content.TrimEnd()) { return }
    if ($PSCmdlet.ShouldProcess($Path, 'Update managed storage settings')) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $fileBackup = Join-Path $backupDir (([guid]::NewGuid().ToString('N')) + '-' + (Split-Path $Path -Leaf))
        if (Test-Path -LiteralPath $Path) { Copy-Item -LiteralPath $Path -Destination $fileBackup }
        @{ path = $Path; backup = $fileBackup; existed = [bool](Test-Path -LiteralPath $Path) } |
            ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $backupDir 'files.jsonl')
        New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force | Out-Null
        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM
    }
}
$managed = [ordered]@{}
if ($JavaHome) { Set-ManagedVariable 'JAVA_HOME' $JavaHome }
foreach ($property in $config.variables.PSObject.Properties) {
    $path = [IO.Path]::GetFullPath((Join-Path $Root $property.Value))
    if (-not $path.StartsWith($Root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Manifest path escapes root: $($property.Name)" }
    $managed[$property.Name] = $path
    if (-not (Test-Path -LiteralPath $path) -and $PSCmdlet.ShouldProcess($path, 'Create storage directory')) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    Set-ManagedVariable $property.Name $path
}
$maven = Join-Path $Root $config.mavenRepository
if (-not (Test-Path -LiteralPath $maven) -and $PSCmdlet.ShouldProcess($maven, 'Create Maven repository')) {
    New-Item -ItemType Directory -Path $maven -Force | Out-Null
}
$opts = [Environment]::GetEnvironmentVariable('MAVEN_OPTS', 'User')
if (-not $opts) { $opts = [Environment]::GetEnvironmentVariable('MAVEN_OPTS', 'Machine') }
$opts = ([regex]::Replace([string]$opts, '(?:"-Dmaven\.repo\.local=[^"]*"|-Dmaven\.repo\.local=(?:"[^"]*"|\S+))', '')).Trim()
$mavenOption = if ($maven -match '\s') { '"-Dmaven.repo.local=' + $maven + '"' } else { '-Dmaven.repo.local=' + $maven }
$managed['MAVEN_OPTS'] = (@($opts, $mavenOption) | Where-Object { $_ }) -join ' '
Set-ManagedVariable 'MAVEN_OPTS' $managed['MAVEN_OPTS']

# pnpm owns its global config; retain unrelated settings and credentials.
$pnpmConfig = Join-Path $env:LOCALAPPDATA 'pnpm/config/config.yaml'
$pnpmText = if (Test-Path -LiteralPath $pnpmConfig) { Get-Content -LiteralPath $pnpmConfig -Raw } else { '' }
foreach ($property in $config.pnpm.PSObject.Properties) {
    $value = (Join-Path $Root $property.Value).Replace("'", "''")
    $line = "$($property.Name): '$value'"
    $pattern = '(?m)^' + [regex]::Escape($property.Name) + ':[^\r\n]*'
    if ([regex]::IsMatch($pnpmText, $pattern)) { $pnpmText = [regex]::Replace($pnpmText, $pattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $line }) }
    else { $pnpmText = $pnpmText.TrimEnd() + "`n$line`n" }
}
Write-ManagedFile $pnpmConfig $pnpmText
# Environment is authoritative for npm/pip cache; keep authentication and other config.
$npmrc = Join-Path $HOME '.npmrc'
if (Test-Path -LiteralPath $npmrc) {
    $text = Get-Content -LiteralPath $npmrc -Raw
    $text = [regex]::Replace($text, '(?m)^\s*(?:cache|store-dir|cache-dir|state-dir|global-dir|global-bin-dir)\s*=[^\r\n]*(?:\r?\n|$)', '')
    Write-ManagedFile $npmrc $text
}
$pipIni = Join-Path $env:APPDATA 'pip/pip.ini'
if (Test-Path -LiteralPath $pipIni) {
    $text = [regex]::Replace((Get-Content -LiteralPath $pipIni -Raw), '(?m)^\s*cache-dir\s*=[^\r\n]*(?:\r?\n|$)', '')
    Write-ManagedFile $pipIni $text
}

$userPaths = @([Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ -and $_.Trim() })
if ($CleanPath) {
    $userPaths = @($userPaths | Where-Object {
        $_ -notmatch '(?i)[\\/]\.pyenv[\\/]|[\\/]mise[\\/]|[\\/]Author Software[\\/]nvm[\\/]+\.nodejs$' -and
        $_ -notmatch '(?i)[\\/]Microsoft Visual Studio[\\/].*(?:[\\/]VC[\\/]Tools[\\/]|[\\/]MSBuild[\\/]|[\\/]Team Tools[\\/]|[\\/]Common7[\\/](?:Tools|IDE)(?:[\\/]?$|[\\/]VC[\\/]VCPackages|[\\/]CommonExtensions|[\\/]Team Tools|[\\/]Extensions))' -and
        $_ -notmatch '(?i)[\\/]Windows Kits[\\/]10[\\/]bin[\\/]|[\\/]Microsoft SDKs[\\/]Windows[\\/]v10\.0A[\\/]|[\\/]Microsoft\.NET[\\/]Framework[\\/]v4\.0\.30319'
    })
    foreach ($name in @('PYENV', 'PYENV_HOME', 'PYENV_ROOT', 'UV_LINK_MODE')) { Set-ManagedVariable $name $null }
}
$additions = @($config.pathVariables | ForEach-Object { $managed[$_] }) +
    @($config.pathDirectories | ForEach-Object { Join-Path $Root $_ }) +
    @((Join-Path $HOME '.local/bin'))
if (Test-Path -LiteralPath (Join-Path $Root 'nvm/.nodejs')) { $additions += Join-Path $Root 'nvm/.nodejs' }
$seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$normalized = @($additions + $userPaths | ForEach-Object {
    $entry = $_.Trim().Replace('/', '\').TrimEnd('\')
    if ($seen.Add($entry)) { $entry }
})
Set-ManagedVariable 'Path' ($normalized -join ';')

if ($RemoveMachineDuplicates) {
    foreach ($name in $managed.Keys) {
        $machine = [Environment]::GetEnvironmentVariable($name, 'Machine')
        $user = [Environment]::GetEnvironmentVariable($name, 'User')
        $exists = (Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').GetValueNames() -contains $name
        if ($exists -and ([string]::IsNullOrEmpty($machine) -or ($user -and $machine -ieq $user))) { Set-ManagedVariable $name $null 'Machine' }
        elseif ($machine) { Write-Warning "Machine $name differs; retained." }
    }
    $machinePaths = @([Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ -and $_.Trim() } | Where-Object {
        -not ($_ -match '(?i)([\\/]nvm4w[\\/]nodejs$|[\\/]AppData[\\/]Local[\\/]nvm$)' -and -not (Test-Path -LiteralPath $_))
    } | Select-Object -Unique)
    Set-ManagedVariable 'Path' ($machinePaths -join ';') 'Machine'
}
if (Test-Path -LiteralPath $backupDir) { Write-Host "Backup: $backupDir" }
Write-Host 'Storage configuration complete. Restart terminals and editors to refresh their environment.'
