<#
.SYNOPSIS
    Installs the repo's OpenCode config, skills, and agent-skills into the user's home directories.

.DESCRIPTION
    Copies opencode/package.json + opencode/config/*.json|jsonc into
    $HOME\.config\opencode\, copies opencode/skills/ into $HOME\.config\opencode\skills\,
    and copies opencode/agent-skills/ into $HOME\.agents\skills\. Re-running is idempotent:
    identical files are skipped silently. Files that differ from the payload are
    backed up to <target>.bak-<yyyyMMdd-HHmmss> before overwrite.

    Uses a fixed manifest of managed files, so -Uninstall removes ONLY files this
    package deploys and leaves any unknown files in the target directories alone.

    Does not require administrator privileges.

.PARAMETER Uninstall
    Remove ONLY the files this package manages (the config files + skill folders
    it deployed). Unknown files in the target dirs are left untouched.

.PARAMETER InstallDir
    Override the destination for the opencode config root. Defaults to
    $HOME\.config\opencode.

.PARAMETER AgentSkillsDir
    Override the destination for agent-skills. Defaults to $HOME\.agents\skills.

.EXAMPLE
    PS> pwsh -File .\Install-OpenCodeConfig.ps1

    Default install: deploys config, internal skills, and agent skills.

.EXAMPLE
    PS> pwsh -File .\Install-OpenCodeConfig.ps1 -Uninstall

    Remove ONLY the files this package manages; leave unknown files alone.

.EXAMPLE
    PS> pwsh -File .\Install-OpenCodeConfig.ps1 -InstallDir 'D:\config\opencode'

    Install into a custom config root.

.NOTES
    Required env vars after install: GITHUB_PERSONAL_ACCESS_TOKEN, CONTEXT7_API_KEY.
    Google provider auth is handled by 'opencode auth login' (projectId is baked
    into the shipped opencode.json).
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [string]$InstallDir = (Join-Path $HOME '.config\opencode'),
    [string]$AgentSkillsDir = (Join-Path $HOME '.agents\skills')
)

$ErrorActionPreference = 'Stop'

# --- Source layout (relative to this script) ---
$ScriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceRoot    = Join-Path $ScriptRoot 'opencode'
$SourceConfig  = Join-Path $SourceRoot 'config'
$SourceSkills  = Join-Path $SourceRoot 'skills'
$SourceAgent   = Join-Path $SourceRoot 'agent-skills'
$SourcePackage = Join-Path $SourceRoot 'package.json'

# --- Managed-file manifest ---
$ConfigFiles = @(
    'opencode.json',
    'oh-my-opencode-slim.json',
    'tui.json',
    'dcp.jsonc',
    'opencode-mem.jsonc',
    'quota-toast.json',
    'package.json'
)

$InternalSkillDirs = @(
    'clonedeps',
    'codemap',
    'deepwork',
    'loop-engineering',
    'oh-my-opencode-slim',
    'reflect',
    'release-smoke-test',
    'simplify',
    'verification-planning',
    'worktrees'
)

$AgentSkillDirs = @(
    'api-security-hardening',
    'authjs-skills',
    'context7-mcp',
    'dotnet-aspire',
    'find-skills',
    'frontend-design',
    'pinokio',
    'understand',
    'understand-chat',
    'understand-dashboard',
    'understand-diff',
    'understand-domain',
    'understand-explain',
    'understand-knowledge',
    'understand-onboard'
)

# Timestamp used for backup suffixing on this run.
$Timestamp = (Get-Date).ToString('yyyyMMdd-HHmmss')

function Write-Status {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host "[opencode] $Message" -ForegroundColor $Color
}

function Test-FilesIdentical {
    param([string]$PathA, [string]$PathB)
    if (-not (Test-Path -LiteralPath $PathA)) { return $false }
    if (-not (Test-Path -LiteralPath $PathB)) { return $false }
    $a = Get-FileHash -LiteralPath $PathA -Algorithm SHA256
    $b = Get-FileHash -LiteralPath $PathB -Algorithm SHA256
    return $a.Hash -eq $b.Hash
}

function Copy-ManagedFile {
    param([string]$Source, [string]$Destination)

    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if (Test-FilesIdentical -PathA $Source -PathB $Destination) {
        return
    }

    if (Test-Path -LiteralPath $Destination) {
        $backup = "$Destination.bak-$Timestamp"
        Copy-Item -LiteralPath $Destination -Destination $backup -Force
        Write-Status "Backed up $Destination -> $backup" -Color Yellow
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-ManagedTree {
    param([string]$SourceDir, [string]$DestDir)

    if (-not (Test-Path -LiteralPath $SourceDir)) { return }
    if (-not (Test-Path -LiteralPath $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    $files = Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Force
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($SourceDir.Length).TrimStart('\', '/')
        $dest = Join-Path $DestDir $rel
        Copy-ManagedFile -Source $f.FullName -Destination $dest
    }
}

# --- Uninstall path ---
if ($Uninstall) {
    Write-Status "==> Uninstalling" -Color Cyan
    $removed = 0

    foreach ($f in $ConfigFiles) {
        $p = Join-Path $InstallDir $f
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            Remove-Item -LiteralPath $p -Force
            Write-Status "  - removed $p"
            $removed++
        }
    }

    foreach ($d in $InternalSkillDirs) {
        $p = Join-Path (Join-Path $InstallDir 'skills') $d
        if ((Test-Path -LiteralPath $p) -and -not ((Get-Item -LiteralPath $p).PSObject.Properties.Match('LinkType').Count -gt 0 -and (Get-Item -LiteralPath $p).LinkType -eq 'SymbolicLink')) {
            Remove-Item -LiteralPath $p -Recurse -Force
            Write-Status "  - removed $p"
            $removed++
        }
    }

    foreach ($d in $AgentSkillDirs) {
        $p = Join-Path $AgentSkillsDir $d
        if ((Test-Path -LiteralPath $p) -and -not ((Get-Item -LiteralPath $p).PSObject.Properties.Match('LinkType').Count -gt 0 -and (Get-Item -LiteralPath $p).LinkType -eq 'SymbolicLink')) {
            Remove-Item -LiteralPath $p -Recurse -Force
            Write-Status "  - removed $p"
            $removed++
        }
    }

    Write-Status "Removed $removed managed file(s)/dir(s)" -Color Green
    Write-Status "Unknown files in $InstallDir and $AgentSkillsDir were left untouched." -Color DarkGray
    Write-Status "Backups (if any) are still available at <original>.bak-$Timestamp" -Color DarkGray
    return
}

# --- Install path ---
if (-not (Test-Path -LiteralPath $SourceRoot)) {
    Write-Error "Source payload not found at $SourceRoot"
    return
}

Write-Status "==> Installing opencode config" -Color Cyan

if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Status "Created $InstallDir" -Color Cyan
}
$SkillsDir = Join-Path $InstallDir 'skills'
if (-not (Test-Path -LiteralPath $SkillsDir)) {
    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $AgentSkillsDir)) {
    New-Item -ItemType Directory -Path $AgentSkillsDir -Force | Out-Null
    Write-Status "Created $AgentSkillsDir" -Color Cyan
}

# Top-level config files
foreach ($f in $ConfigFiles) {
    if ($f -eq 'package.json') {
        $src = $SourcePackage
    }
    else {
        $src = Join-Path $SourceConfig $f
    }
    if (-not (Test-Path -LiteralPath $src)) {
        Write-Warning "Source file missing, skipping: $src"
        continue
    }
    $dest = Join-Path $InstallDir $f
    Copy-ManagedFile -Source $src -Destination $dest
}

# Internal skills -> $InstallDir\skills\
Copy-ManagedTree -SourceDir $SourceSkills -DestDir $SkillsDir

# Agent skills -> $AgentSkillsDir\
Copy-ManagedTree -SourceDir $SourceAgent -DestDir $AgentSkillsDir

Write-Status "Install complete" -Color Green

Write-Host ""
Write-Status "==> Action required: env vars" -Color Cyan
Write-Host "  Set these environment variables before launching OpenCode:" -ForegroundColor Gray
Write-Host ""
Write-Host "    [System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','<your-github-pat>','User')" -ForegroundColor Gray
Write-Host "    [System.Environment]::SetEnvironmentVariable('CONTEXT7_API_KEY','ctx7sk-<your-key>','User')" -ForegroundColor Gray
Write-Host ""
Write-Status "Google provider auth happens via:  opencode auth login" -Color Gray
Write-Status "(projectId is baked into opencode.json and does not need to be set)" -Color DarkGray
Write-Host ""
Write-Status "==> Restart OpenCode to pick up the new config" -Color Cyan
Write-Status "Re-launch the opencode binary or exit/restart the opencode TUI." -Color Gray
