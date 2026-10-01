<#
.SYNOPSIS
    Installs and configures Herdr workspace manager, plugins, and agent integrations.

.DESCRIPTION
    Deploys Herdr configuration (config.toml) and Auto Title plugin configuration (config.env).
    Builds the local herdr-auto-title plugin from source and links it into Herdr via
    'herdr plugin link', ensuring local fixes are preserved. Also installs the agent state
    integrations for Antigravity CLI, Claude Code, Codex, GitHub Copilot CLI, and OpenCode.

.PARAMETER WhatIf
    Previews the changes without copying files or modifying live state.

.PARAMETER SkipBuild
    Skips compiling the herdr-auto-title binary with Go before linking.

.PARAMETER SkipIntegrations
    Skips installing agent lifecycle integrations.

.EXAMPLE
    pwsh -File .\Install-HerdrConfig.ps1
    Deploys configurations, compiles auto-title plugin, links it to Herdr, and installs integrations.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PluginDir,
    [switch]$SkipBuild,
    [switch]$SkipIntegrations
)

$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step { param([string]$Message) Write-Host "[herdr-setup] $Message" -ForegroundColor Cyan }
function Write-Success { param([string]$Message) Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Host "  [WARN] $Message" -ForegroundColor Yellow }

# 1. Determine destination paths
$RunningOnWindows = ($null -ne $IsWindows -and $IsWindows) -or ($env:OS -eq 'Windows_NT')
if ($RunningOnWindows) {
    $HerdrConfigDir = Join-Path $env:APPDATA 'herdr'
    $AutoTitleConfigDir = Join-Path $HOME '.config\herdr-auto-title'
} else {
    $XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    $HerdrConfigDir = Join-Path $XdgConfig 'herdr'
    $AutoTitleConfigDir = Join-Path $XdgConfig 'herdr-auto-title'
}

$HerdrConfigFile = Join-Path $HerdrConfigDir 'config.toml'
$AutoTitleConfigFile = Join-Path $AutoTitleConfigDir 'config.env'

$SourceConfigFile = if (Test-Path (Join-Path $ScriptRoot 'config.toml')) { Join-Path $ScriptRoot 'config.toml' } else { Join-Path $ScriptRoot 'config\config.toml' }
$SourceAutoTitleEnv = if (Test-Path (Join-Path $ScriptRoot 'config.env')) { Join-Path $ScriptRoot 'config.env' } else { Join-Path $ScriptRoot 'config\herdr-auto-title\config.env' }

$PluginSourceDir = $null
$CandidatePluginDirs = @()
if ($PluginDir) {
    $CandidatePluginDirs += $PluginDir
}
$CandidatePluginDirs += @(
    'Z:\Personal\herdr-auto-title',
    (Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptRoot)) 'herdr-auto-title')
)
foreach ($Cand in $CandidatePluginDirs) {
    if ($Cand -and (Test-Path (Join-Path $Cand 'herdr-plugin.toml'))) {
        $PluginSourceDir = (Resolve-Path $Cand).Path
        break
    }
}

# 2. Deploy Herdr config.toml
Write-Step "Checking Herdr configuration ($HerdrConfigFile)..."
if (-not (Test-Path $HerdrConfigDir)) {
    if ($PSCmdlet.ShouldProcess($HerdrConfigDir, "Create directory")) {
        New-Item -ItemType Directory -Path $HerdrConfigDir -Force | Out-Null
    }
}

if (Test-Path $SourceConfigFile) {
    $DeployConfig = $true
    if (Test-Path $HerdrConfigFile) {
        $SourceHash = (Get-FileHash -Path $SourceConfigFile -Algorithm SHA256).Hash
        $TargetHash = (Get-FileHash -Path $HerdrConfigFile -Algorithm SHA256).Hash
        if ($SourceHash -eq $TargetHash) {
            Write-Success "config.toml is already up to date"
            $DeployConfig = $false
        } else {
            $BackupFile = "$HerdrConfigFile.bak-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
            if ($PSCmdlet.ShouldProcess($HerdrConfigFile, "Backup to $BackupFile")) {
                Copy-Item -Path $HerdrConfigFile -Destination $BackupFile -Force
            }
        }
    }

    if ($DeployConfig) {
        if ($PSCmdlet.ShouldProcess($HerdrConfigFile, "Deploy config.toml")) {
            Copy-Item -Path $SourceConfigFile -Destination $HerdrConfigFile -Force
            Write-Success "Deployed config.toml"
        }
    }
}

# 3. Deploy Auto Title config.env
Write-Step "Checking Auto Title configuration ($AutoTitleConfigFile)..."
if (-not (Test-Path $AutoTitleConfigDir)) {
    if ($PSCmdlet.ShouldProcess($AutoTitleConfigDir, "Create directory")) {
        New-Item -ItemType Directory -Path $AutoTitleConfigDir -Force | Out-Null
    }
}

if (Test-Path $SourceAutoTitleEnv) {
    $DeployEnv = $true
    if (Test-Path $AutoTitleConfigFile) {
        $SourceHash = (Get-FileHash -Path $SourceAutoTitleEnv -Algorithm SHA256).Hash
        $TargetHash = (Get-FileHash -Path $AutoTitleConfigFile -Algorithm SHA256).Hash
        if ($SourceHash -eq $TargetHash) {
            Write-Success "Auto Title config.env is already up to date"
            $DeployEnv = $false
        } else {
            $BackupFile = "$AutoTitleConfigFile.bak-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
            if ($PSCmdlet.ShouldProcess($AutoTitleConfigFile, "Backup to $BackupFile")) {
                Copy-Item -Path $AutoTitleConfigFile -Destination $BackupFile -Force
            }
        }
    }

    if ($DeployEnv) {
        if ($PSCmdlet.ShouldProcess($AutoTitleConfigFile, "Deploy config.env")) {
            Copy-Item -Path $SourceAutoTitleEnv -Destination $AutoTitleConfigFile -Force
            Write-Success "Deployed config.env"
        }
    }
}

# 4. Build and link herdr-auto-title plugin
if (Get-Command herdr -ErrorAction SilentlyContinue) {
    if ($PluginSourceDir) {
        if (-not $SkipBuild) {
            if (Get-Command go -ErrorAction SilentlyContinue) {
                Write-Step "Building herdr-auto-title plugin binary in $PluginSourceDir..."
                $BinaryName = if ($RunningOnWindows) { 'herdr-auto-title.exe' } else { 'herdr-auto-title' }
                $BinaryPath = Join-Path $PluginSourceDir $BinaryName
                if ($PSCmdlet.ShouldProcess($BinaryPath, "go build")) {
                    Push-Location $PluginSourceDir
                    try {
                        & go build -o $BinaryName ./cmd/herdr-auto-title
                        Write-Success "Compiled $BinaryName"
                    } finally {
                        Pop-Location
                    }
                }
            } else {
                Write-Warn "Go is not in PATH. Skipping build (existing binary will be linked if present)."
            }
        }

        Write-Step "Linking local herdr-auto-title plugin from $PluginSourceDir to Herdr..."
        if ($PSCmdlet.ShouldProcess($PluginSourceDir, "herdr plugin link")) {
            & herdr plugin link $PluginSourceDir
            Write-Success "Linked herdr-auto-title to Herdr"
        }
    } else {
        Write-Warn "Local herdr-auto-title repository not found. Pass -PluginDir <path> or clone to Z:\Personal\herdr-auto-title."
    }

    # 5. Install agent integrations
    if (-not $SkipIntegrations) {
        Write-Step "Configuring agent lifecycle integrations..."
        $Integrations = @('antigravity-cli', 'claude', 'codex', 'copilot', 'opencode')
        foreach ($Integration in $Integrations) {
            if ($PSCmdlet.ShouldProcess($Integration, "herdr integration install")) {
                try {
                    & herdr integration install $Integration 2>$null
                    Write-Success "Configured integration: $Integration"
                } catch {
                    Write-Warn "Could not configure $Integration (client config folder may not exist yet)"
                }
            }
        }
    }

    # 6. Refresh running Herdr server
    Write-Step "Reloading running Herdr instance..."
    try {
        & herdr server reload-config 2>$null
        & herdr plugin action invoke herdr.auto-title.restart 2>$null
        Write-Success "Reloaded Herdr config and restarted Auto Title"
    } catch {
        # Server might not be running
    }
} else {
    Write-Warn "Herdr command not found in PATH. Install Herdr from https://herdr.dev to link plugin."
}

Write-Host "`nSetup complete!" -ForegroundColor Green
