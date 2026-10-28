<#
.SYNOPSIS
    Installs and configures Herdr workspace manager, plugins, and agent integrations.

.DESCRIPTION
    Deploys Herdr configuration (config.toml), Auto Title plugin configuration (config.env),
    and plugin-specific configurations (herdr.auto-title, herdr-radar, memex).
    Installs herdr-radar everywhere; Memex is skipped on Windows (macOS/Linux only).
    Installs the official herdr-theme-picker (qintmb/herdr-theme-picker) and herdr-auto-title
    (kryptamine/herdr-auto-title) from GitHub, or links a local checkout via
    'herdr plugin link' (with optional Go compilation) when -PluginDir is given.
    Also installs agent lifecycle integrations for Antigravity CLI, Claude Code, Codex,
    GitHub Copilot CLI, and OpenCode, and reloads the live Herdr server.

.PARAMETER PluginDir
    Path to a local checkout of herdr-auto-title to build and link. If omitted, the official release is installed from GitHub.

.PARAMETER SkipBuild
    Skips compiling a -PluginDir checkout with Go before linking. Useful when the binary
    is already compiled.

.PARAMETER SkipIntegrations
    Skips installing agent lifecycle integrations.

.EXAMPLE
    pwsh -File .\Install-HerdrConfig.ps1 -WhatIf
    Previews the deployment actions.

.EXAMPLE
    pwsh -File .\Install-HerdrConfig.ps1 -SkipBuild
    Deploys configurations, links existing auto-title build without recompiling, and configures integrations.
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
    $AutoTitleAppDataDir = Join-Path $env:APPDATA 'herdr-auto-title'
} else {
    $XdgConfig = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
    $HerdrConfigDir = Join-Path $XdgConfig 'herdr'
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX) -and
        (-not (Test-Path $HerdrConfigDir)) -and
        (Test-Path (Join-Path $HOME 'Library/Application Support/herdr'))) {
        $HerdrConfigDir = Join-Path $HOME 'Library/Application Support/herdr'
    }
    $AutoTitleConfigDir = Join-Path $XdgConfig 'herdr-auto-title'
    $AutoTitleAppDataDir = $null
}

$HerdrConfigFile = Join-Path $HerdrConfigDir 'config.toml'
$AutoTitleConfigFile = Join-Path $AutoTitleConfigDir 'config.env'
$HerdrPluginConfigDir = Join-Path $HerdrConfigDir 'plugins\config'

$SourceConfigFile = if (Test-Path (Join-Path $ScriptRoot 'config.toml')) { Join-Path $ScriptRoot 'config.toml' } else { Join-Path $ScriptRoot 'config\config.toml' }
$SourceAutoTitleEnv = if (Test-Path (Join-Path $ScriptRoot 'config.env')) { Join-Path $ScriptRoot 'config.env' } else { Join-Path $ScriptRoot 'config\herdr-auto-title\config.env' }
$SourcePluginConfigDir = Join-Path $ScriptRoot 'plugins\config'

# A local herdr-auto-title checkout is linked only when -PluginDir is given;
# otherwise the official release is installed from GitHub.
$PluginSourceDir = $null
if ($PluginDir) {
    if (Test-Path (Join-Path $PluginDir 'herdr-plugin.toml')) {
        $PluginSourceDir = (Resolve-Path $PluginDir).Path
    } else {
        throw "No herdr-plugin.toml found in -PluginDir '$PluginDir'."
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
            Write-Success "Deployed config.env to $AutoTitleConfigDir"
        }
    }

    # Also sync to AppData herdr-auto-title if on Windows
    if ($AutoTitleAppDataDir) {
        if (-not (Test-Path $AutoTitleAppDataDir)) {
            if ($PSCmdlet.ShouldProcess($AutoTitleAppDataDir, "Create directory")) {
                New-Item -ItemType Directory -Path $AutoTitleAppDataDir -Force | Out-Null
            }
        }
        $AppDataConfigFile = Join-Path $AutoTitleAppDataDir 'config.env'
        if ($PSCmdlet.ShouldProcess($AppDataConfigFile, "Deploy config.env")) {
            Copy-Item -Path $SourceAutoTitleEnv -Destination $AppDataConfigFile -Force
        }
    }
}

# 4. Deploy plugin-specific configurations (plugins/config/)
Write-Step "Checking plugin-specific configurations..."
if (Test-Path $SourcePluginConfigDir) {
    if (-not (Test-Path $HerdrPluginConfigDir)) {
        if ($PSCmdlet.ShouldProcess($HerdrPluginConfigDir, "Create plugin config directory")) {
            New-Item -ItemType Directory -Path $HerdrPluginConfigDir -Force | Out-Null
        }
    }

    # Copy all plugin configuration directories
    # Memex has no Windows build, so its config directory is not deployed there.
    Get-ChildItem -Path $SourcePluginConfigDir -Directory | Where-Object { -not ($RunningOnWindows -and $_.Name -eq 'nicosuave.memex') } | ForEach-Object {
        $TargetSubDir = Join-Path $HerdrPluginConfigDir $_.Name
        if (-not (Test-Path $TargetSubDir)) {
            if ($PSCmdlet.ShouldProcess($TargetSubDir, "Create directory")) {
                New-Item -ItemType Directory -Path $TargetSubDir -Force | Out-Null
            }
        }
        Get-ChildItem -Path $_.FullName -File | ForEach-Object {
            $TargetFile = Join-Path $TargetSubDir $_.Name
            $NeedCopy = $true
            if (Test-Path $TargetFile) {
                $SrcH = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
                $DstH = (Get-FileHash -Path $TargetFile -Algorithm SHA256).Hash
                if ($SrcH -eq $DstH) { $NeedCopy = $false }
            }
            if ($NeedCopy) {
                if ($PSCmdlet.ShouldProcess($TargetFile, "Deploy plugin file $($_.Name)")) {
                    Copy-Item -Path $_.FullName -Destination $TargetFile -Force
                    Write-Success "Deployed plugin config: $($_.Directory.Name)/$($_.Name)"
                }
            }
        }
    }

    # Ensure herdr-auto-title plugin config has the canonical config.env
    $PluginAutoTitleDir = Join-Path $HerdrPluginConfigDir 'herdr.auto-title'
    if (-not (Test-Path $PluginAutoTitleDir)) {
        if ($PSCmdlet.ShouldProcess($PluginAutoTitleDir, "Create directory")) {
            New-Item -ItemType Directory -Path $PluginAutoTitleDir -Force | Out-Null
        }
    }
    $PluginAutoTitleEnv = Join-Path $PluginAutoTitleDir 'config.env'
    if ($PSCmdlet.ShouldProcess($PluginAutoTitleEnv, "Deploy Auto Title config.env")) {
        Copy-Item -Path $SourceAutoTitleEnv -Destination $PluginAutoTitleEnv -Force
        Write-Success "Synced config.env to $PluginAutoTitleDir"
    }
}

# 5. Herdr CLI operations (plugins and integrations)
if (Get-Command herdr -ErrorAction SilentlyContinue) {
    # 5.1 Install the official herdr-theme-picker (qintmb/herdr-theme-picker; Windows support is upstream)
    Write-Step "Checking herdr-theme-picker plugin..."
    $ThemeRepo = if ($env:HERDR_THEME_PICKER_REPO) { $env:HERDR_THEME_PICKER_REPO } else { 'qintmb/herdr-theme-picker' }
    $InstalledPlugins = (& herdr plugin list 2>&1 | Out-String)
    if ($InstalledPlugins -match 'herdr-theme-picker[^\r\n]*local:') {
        Write-Warn "herdr-theme-picker is linked from a local checkout; run 'herdr plugin unlink herdr-theme-picker' to switch to the official release."
    } elseif ($InstalledPlugins -match 'herdr-theme-picker') {
        Write-Success "herdr-theme-picker is already installed (update with: herdr plugin update herdr-theme-picker --yes)"
        & herdr plugin enable herdr-theme-picker 2>$null | Out-Null
    } else {
        Write-Step "Installing herdr-theme-picker from GitHub ($ThemeRepo)..."
        if ($PSCmdlet.ShouldProcess($ThemeRepo, "herdr plugin install")) {
            $ThemeArgs = @('plugin', 'install', $ThemeRepo, '--yes')
            if ($env:HERDR_THEME_PICKER_REF) { $ThemeArgs += @('--ref', $env:HERDR_THEME_PICKER_REF) }
            & herdr @ThemeArgs
            if ($LASTEXITCODE -eq 0) {
                & herdr plugin enable herdr-theme-picker 2>$null | Out-Null
                Write-Success "Installed herdr-theme-picker"
            } else {
                Write-Warn "Could not install herdr-theme-picker from $ThemeRepo"
            }
        }
    }

    # 5.2 herdr-auto-title: official release by default, local checkout with -PluginDir
    if ($PluginSourceDir) {
        $BinaryName = if ($RunningOnWindows) { 'herdr-auto-title.exe' } else { 'herdr-auto-title' }
        $BinaryPath = Join-Path $PluginSourceDir $BinaryName

        if (-not $SkipBuild) {
            if (Get-Command go -ErrorAction SilentlyContinue) {
                Write-Step "Building herdr-auto-title plugin binary in $PluginSourceDir..."
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
        } else {
            Write-Success "Skipping build as requested (using existing $BinaryPath)"
        }

        Write-Step "Linking local herdr-auto-title plugin from $PluginSourceDir to Herdr..."
        if ($PSCmdlet.ShouldProcess($PluginSourceDir, "herdr plugin link")) {
            & herdr plugin link $PluginSourceDir
            & herdr plugin enable herdr.auto-title 2>$null
            Write-Success "Linked herdr-auto-title to Herdr"
        }
    } else {
        $InstalledPlugins = (& herdr plugin list 2>&1 | Out-String)
        if ($InstalledPlugins -match 'herdr\.auto-title[^\r\n]*local:') {
            Write-Warn "herdr-auto-title is linked from a local checkout; run 'herdr plugin unlink herdr.auto-title' to switch to the official release."
        } elseif ($InstalledPlugins -match 'herdr\.auto-title') {
            Write-Success "herdr-auto-title is already installed (update with: herdr plugin update herdr.auto-title --yes)"
            & herdr plugin enable herdr.auto-title 2>$null
        } else {
            $AutoTitleRepo = if ($env:HERDR_AUTO_TITLE_REPO) { $env:HERDR_AUTO_TITLE_REPO } else { 'kryptamine/herdr-auto-title' }
            Write-Step "Installing herdr-auto-title from GitHub ($AutoTitleRepo)..."
            if ($PSCmdlet.ShouldProcess($AutoTitleRepo, "herdr plugin install")) {
                & herdr plugin install $AutoTitleRepo --yes
                if ($LASTEXITCODE -eq 0) {
                    & herdr plugin enable herdr.auto-title 2>$null
                    Write-Success "Installed herdr-auto-title"
                } else {
                    Write-Warn "Could not install herdr-auto-title from $AutoTitleRepo"
                }
            }
        }
    }

    # 5.2a Herdr Radar (agent sidebar + tab bar). Supported on Windows, macOS and Linux; needs Node.
    $RadarRepo = if ($env:HERDR_RADAR_REPO) { $env:HERDR_RADAR_REPO } else { 'hhdebb/herdr-radar' }
    $InstalledPlugins = (& herdr plugin list 2>&1 | Out-String)
    if ($InstalledPlugins -match 'hhdebb\.herdr-radar') {
        Write-Success "herdr-radar is already installed (update with: herdr plugin update hhdebb.herdr-radar --yes)"
        & herdr plugin enable hhdebb.herdr-radar 2>$null | Out-Null
    } elseif (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        Write-Warn "Node.js is not in PATH; skipping herdr-radar (install Node, then rerun)."
    } else {
        Write-Step "Installing herdr-radar from GitHub ($RadarRepo)..."
        if ($PSCmdlet.ShouldProcess($RadarRepo, "herdr plugin install")) {
            $RadarArgs = @('plugin', 'install', $RadarRepo, '--yes')
            if ($env:HERDR_RADAR_REF) { $RadarArgs += @('--ref', $env:HERDR_RADAR_REF) }
            & herdr @RadarArgs
            if ($LASTEXITCODE -eq 0) {
                & herdr plugin enable hhdebb.herdr-radar 2>$null | Out-Null
                Write-Success "Installed herdr-radar"
            } else {
                Write-Warn "Could not install herdr-radar from $RadarRepo"
            }
        }
    }
    # config.toml was just redeployed from the repo, so rewrite Radar's managed sidebar/tab-bar/theme blocks.
    if ((& herdr plugin list 2>&1 | Out-String) -match 'hhdebb\.herdr-radar') {
        if ($PSCmdlet.ShouldProcess("hhdebb.herdr-radar", "configure managed config blocks")) {
            & herdr plugin action invoke hhdebb.herdr-radar.configure 2>&1 | Out-Null
            Write-Success "Radar managed config blocks applied"
        }
    }

    # 5.2b Memex ships no Windows build (its manifest lists macOS and Linux only).
    if ($RunningOnWindows) {
        Write-Warn "Skipping nicosuave/memex: it supports macOS and Linux only. Its config is in ai/herdr/memex and ai/herdr/plugins/config/nicosuave.memex for those hosts."
    }

    # 5.3 Install agent integrations
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

    # 5.4 Refresh running Herdr server
    Write-Step "Reloading running Herdr instance..."
    if ($PSCmdlet.ShouldProcess("Herdr server", "Reload config and restart auto-title")) {
        try {
            & herdr server reload-config 2>$null
            & herdr plugin action invoke herdr.auto-title.restart 2>$null
            Write-Success "Reloaded Herdr config and restarted Auto Title"
        } catch {
            # Server might not be running
        }
    }
} else {
    Write-Warn "Herdr command not found in PATH. Install Herdr from https://herdr.dev to link plugin."
}

Write-Host "`nHerdr setup complete!" -ForegroundColor Green
