<#
.SYNOPSIS
    Backs up local Herdr and plugin configurations into repository.

.DESCRIPTION
    Exports active Herdr configuration (config.toml), Auto Title plugin configuration (config.env),
    and plugin-specific configuration directories (plugins/config/) from this machine into the ai/herdr/ directory for version control and cross-platform syncing.

.EXAMPLE
    pwsh -File .\Backup-HerdrConfig.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Message) Write-Host "[herdr-backup] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }

$RunningOnWindows = ($null -ne $IsWindows -and $IsWindows) -or ($env:OS -eq 'Windows_NT')
if ($RunningOnWindows) {
    $HerdrConfigDir = Join-Path $env:APPDATA 'herdr'
    $AutoTitleConfigDir = Join-Path $HOME '.config\herdr-auto-title'
} else {
    $XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    $HerdrConfigDir = Join-Path $XdgConfig 'herdr'
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX) -and
        (-not (Test-Path $HerdrConfigDir)) -and
        (Test-Path (Join-Path $HOME 'Library/Application Support/herdr'))) {
        $HerdrConfigDir = Join-Path $HOME 'Library/Application Support/herdr'
    }
    $AutoTitleConfigDir = Join-Path $XdgConfig 'herdr-auto-title'
}

$HerdrConfigFile = Join-Path $HerdrConfigDir 'config.toml'
$AutoTitleConfigFile = Join-Path $AutoTitleConfigDir 'config.env'
$HerdrPluginConfigDir = Join-Path $HerdrConfigDir 'plugins\config'

# 1. Back up config.toml
Write-Step "Backing up Herdr core configuration..."
if (Test-Path $HerdrConfigFile) {
    # Radar's managed blocks hold machine paths; its configure action rewrites them on install.
    $Config = (Get-Content -Path $HerdrConfigFile -Raw) -replace '(?ms)^# >>> herdr-radar.*?^# <<< herdr-radar[^
]*?
?', ''
    Set-Content -Path (Join-Path $ScriptRoot 'config.toml') -Value $Config -NoNewline
    Write-Success "Backed up config.toml (without Radar's managed blocks)"
} else {
    Write-Warn "No config.toml found at $HerdrConfigDir"
}

# 2. Back up config.env
Write-Step "Backing up herdr-auto-title configuration..."
if (Test-Path $AutoTitleConfigFile) {
    Copy-Item -Path $AutoTitleConfigFile -Destination (Join-Path $ScriptRoot 'config.env') -Force
    Write-Success "Backed up config.env"
} else {
    $AltEnv = Join-Path $HerdrPluginConfigDir 'herdr.auto-title\config.env'
    if (Test-Path $AltEnv) {
        Copy-Item -Path $AltEnv -Destination (Join-Path $ScriptRoot 'config.env') -Force
        Write-Success "Backed up config.env (from plugins/config)"
    } else {
        Write-Warn "No config.env found at $AutoTitleConfigFile"
    }
}

# 3. Back up plugin-specific configs
Write-Step "Backing up plugin-specific configurations..."
$DestPluginConfigDir = Join-Path $ScriptRoot 'plugins\config'
if (Test-Path $HerdrPluginConfigDir) {
    if (-not (Test-Path $DestPluginConfigDir)) {
        New-Item -ItemType Directory -Path $DestPluginConfigDir -Force | Out-Null
    }
    # herdr.auto-title only holds a copy of config.env, which is backed up above.
    Get-ChildItem -Path $HerdrPluginConfigDir -Directory | Where-Object { $_.Name -ne 'herdr.auto-title' } | ForEach-Object {
        $DestDir = Join-Path $DestPluginConfigDir $_.Name
        if (-not (Test-Path $DestDir)) {
            New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
        }
        Get-ChildItem -Path $_.FullName -File | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $DestDir $_.Name) -Force
        }
    }
    Write-Success "Backed up plugin configs to $DestPluginConfigDir"
}

Write-Host "`nHerdr configurations successfully backed up!" -ForegroundColor Green
