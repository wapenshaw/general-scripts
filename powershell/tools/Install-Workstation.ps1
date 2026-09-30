<#
.SYNOPSIS
    First-run Windows workstation bootstrap (winget + PowerShell profile).

.DESCRIPTION
    Orchestrates a failsafe first-run on Windows 11 (PowerShell 7 + Windows
    Terminal):

      1. Ensure winget (App Installer) is available; try a repair if missing
      2. Install the curated winget packages via Install-Essentials.ps1
      3. Deploy the modular PowerShell profile via Install-Profile.ps1

    Each step continues after a failure so a missing package never blocks the
    profile install. Does not move special folders, import env snapshots, or
    set Z:\Packages paths — those stay in docs/FRESH-INSTALL.md (steps 4–6)
    and should run before this script on a brand-new box so runtimes/tools write
    into the relocated caches.

    Idempotent. Re-run any time.

.PARAMETER Assurant
    Also install Assurant modules and set $env:PS_ASSURANT = '1' in the profile
    loader. The default is the personal profile. Mirrors ./linux/install.sh
    --assurant and ./macos/install.zsh --assurant.

.PARAMETER SkipPackages
    Skip winget package install; only deploy the profile.

.PARAMETER SkipProfile
    Skip profile deploy; only install winget packages.

.PARAMETER StarshipTheme
    Explicit Starship theme override. Omission preserves an existing theme.

.PARAMETER List
    Print the winget package ids that would be installed and exit.

.EXAMPLE
    PS> pwsh -File .\powershell\tools\Install-Workstation.ps1

    Install essentials + utilities, then the PowerShell profile.

.EXAMPLE
    PS> pwsh -File .\powershell\tools\Install-Workstation.ps1 -Assurant

    Same, with Assurant/Astra modules.

.EXAMPLE
    PS> pwsh -File .\powershell\tools\Install-Workstation.ps1 -SkipPackages

    Profile only (packages already installed).

.NOTES
    Requires PowerShell 7. Elevated recommended so winget can install
    machine-scoped packages. Does not install PowerShell itself.
#>
[CmdletBinding()]
param(
    [switch]$Assurant,
    [switch]$SkipPackages,
    [switch]$SkipProfile,
    [string]$StarshipTheme,
    [switch]$List
)

$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$EssentialsScript = Join-Path $PSScriptRoot 'Install-Essentials.ps1'
$ProfileScript = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'profile') 'Install-Profile.ps1'

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-WarnStep {
    param([string]$Message)
    Write-Warning $Message
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-WingetIfMissing {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Ok "winget: $(winget --version 2>$null)"
        return $true
    }

    Write-WarnStep "winget is not on PATH. Trying App Installer repair."

    $bundle = 'https://aka.ms/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $bundlePath = Join-Path ([System.IO.Path]::GetTempPath()) "Microsoft.DesktopAppInstaller-$([guid]::NewGuid()).msixbundle"
    try {
        Write-Host "Downloading App Installer bundle..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $bundle -OutFile $bundlePath -ErrorAction Stop
        Add-AppxPackage -Path $bundlePath -ErrorAction Stop
    } catch {
        Write-WarnStep "App Installer repair failed: $($_.Exception.Message)"
        Write-Host "Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Yellow
        return $false
    } finally {
        Remove-Item -LiteralPath $bundlePath -Force -ErrorAction SilentlyContinue
    }

    $windowsApps = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if ((Test-Path -LiteralPath (Join-Path $windowsApps 'winget.exe')) -and
        ($env:PATH -notlike "*$windowsApps*")) {
        $env:PATH = "$windowsApps;$env:PATH"
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Ok "winget is available after repair"
        return $true
    }

    Write-WarnStep "winget still not on PATH. Open a new terminal after installing App Installer."
    return $false
}

if ($List) {
    if (-not (Test-Path -LiteralPath $EssentialsScript)) {
        throw "Install-Essentials.ps1 not found at $EssentialsScript"
    }
    & $EssentialsScript -List
    return
}

Write-Host ""
Write-Host "Windows workstation bootstrap" -ForegroundColor Cyan
Write-Host "Repo:    $RepoRoot"
Write-Host "Profile: $(if ($Assurant) { 'personal + assurant' } else { 'personal' })"
Write-Host "Theme:   $(if ($StarshipTheme) { $StarshipTheme } else { 'preserve existing (nova if missing)' })"

if (-not (Test-IsAdmin)) {
    Write-Host ""
    Write-WarnStep "Not running elevated. Some winget packages may fail; the rest will continue."
}

$packageFailed = $false
$profileFailed = $false

if (-not $SkipPackages) {
    Write-Step "winget packages"

    if (-not (Install-WingetIfMissing)) {
        Write-WarnStep "Skipping package install because winget is unavailable"
        $packageFailed = $true
    } elseif (-not (Test-Path -LiteralPath $EssentialsScript)) {
        Write-WarnStep "Install-Essentials.ps1 missing at $EssentialsScript"
        $packageFailed = $true
    } else {
        try {
            $global:LASTEXITCODE = 0
            & $EssentialsScript
            $essentialsExitCode = [int]$LASTEXITCODE
            if ($essentialsExitCode -ne 0) {
                Write-WarnStep "Install-Essentials.ps1 exited $essentialsExitCode — continuing"
                $packageFailed = $true
            } else {
                Write-Ok "winget package pass finished"
            }
        } catch {
            Write-WarnStep "Install-Essentials.ps1 failed: $($_.Exception.Message)"
            $packageFailed = $true
        }
    }
} else {
    Write-Step "Skipping winget packages (-SkipPackages)"
}

if (-not $SkipProfile) {
    Write-Step "PowerShell profile"

    if (-not (Test-Path -LiteralPath $ProfileScript)) {
        Write-WarnStep "Install-Profile.ps1 missing at $ProfileScript"
        $profileFailed = $true
    } else {
        $profileArgs = @{}
        if ($StarshipTheme) { $profileArgs['StarshipTheme'] = $StarshipTheme }
        if ($Assurant) { $profileArgs['Assurant'] = $true }

        try {
            $global:LASTEXITCODE = 0
            & $ProfileScript @profileArgs
            $profileExitCode = [int]$LASTEXITCODE
            if ($profileExitCode -ne 0) {
                Write-WarnStep "Install-Profile.ps1 exited $profileExitCode"
                $profileFailed = $true
            } else {
                Write-Ok "PowerShell profile deployed"
            }
        } catch {
            Write-WarnStep "Install-Profile.ps1 failed: $($_.Exception.Message)"
            $profileFailed = $true
        }
    }
} else {
    Write-Step "Skipping PowerShell profile (-SkipProfile)"
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "  Bootstrap finished." -ForegroundColor Green
Write-Host "  Restart Windows Terminal so new shims" -ForegroundColor Green
Write-Host "  (starship, zoxide, cargo) are on PATH." -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

Write-Host ""
Write-Host "Not done by this script (see docs/FRESH-INSTALL.md):" -ForegroundColor DarkGray
Write-Host "  - Move-Special-Folders.ps1"
Write-Host "  - Set-DevPackagePaths.ps1 (desired storage manifest)"
Write-Host "  - Install-NodeToolchain.ps1 and uv Python/tool setup"
Write-Host "  - Registry / network / shutdown tweaks"

if ($packageFailed -or $profileFailed) {
    Write-Host ""
    if ($packageFailed) { Write-WarnStep "Package step reported problems" }
    if ($profileFailed) { Write-WarnStep "Profile step reported problems" }
    exit 1
}
