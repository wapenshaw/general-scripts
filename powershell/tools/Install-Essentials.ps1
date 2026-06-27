<#
.SYNOPSIS
    One-shot winget installer for a fresh Windows dev box.

.DESCRIPTION
    Runs winget install for the package lists defined in this script:
    - Essentials: PowerToys, Windows Terminal, Git, 7-Zip, VS Code, Notepad++
    - Utilities:  zoxide, fzf, starship, bat, eza, ripgrep, fd, lazygit, delta, jq, yq

    Idempotent. winget skips packages that are already installed at the requested
    version. Run from an elevated PowerShell session - some packages need admin
    and winget will silently fail per-package otherwise.

.PARAMETER Essentials
    Install the OS-level essentials only.

.PARAMETER Utilities
    Install the shell/CLI utilities only.

.PARAMETER List
    Print the package IDs that would be installed and exit. Useful for review
    or piping to a log.

.EXAMPLE
    PS> .\Install-Essentials.ps1

    Install everything (default).

.EXAMPLE
    PS> .\Install-Essentials.ps1 -Utilities

    Install just the shell utilities, skipping essentials.

.EXAMPLE
    PS> .\Install-Essentials.ps1 -List

    Show all package IDs without installing.

.NOTES
    Requires winget (App Installer from Microsoft Store). Does not install
    PowerShell itself - see docs/FRESH-INSTALL.md for the manual install
    procedure, which must happen first.
#>
[CmdletBinding()]
param(
    [switch]$Essentials,
    [switch]$Utilities,
    [switch]$List
)

$ErrorActionPreference = "Stop"

$EssentialsList = @(
    "Microsoft.PowerToys"
    "Microsoft.WindowsTerminal"
    "Git.Git"
    "7zip.7zip"
    "Microsoft.VisualStudioCode"
    "Notepad++.Notepad++"
)

$UtilitiesList = @(
    "ajeetdsouza.zoxide"
    "junegunn.fzf"
    "starship.starship"
    "sharkdp.bat"
    "eza-community.eza"
    "BurntSushi.ripgrep.MSVC"
    "sharkdp.fd"
    "JesseDuffield.lazygit"
    "dan-t.delta"
    "jqlang.jq"
    "MikeFarah.yq"
)

if ($List) {
    if (-not $Essentials -and -not $Utilities) {
        $Essentials = $true
        $Utilities  = $true
    }
    if ($Essentials) { $EssentialsList | ForEach-Object { Write-Host "essentials: $_" } }
    if ($Utilities)  { $UtilitiesList  | ForEach-Object { Write-Host "utilities:  $_" } }
    return
}

if (-not $Essentials -and -not $Utilities) {
    $Essentials = $true
    $Utilities  = $true
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found on PATH. Install App Installer from the Microsoft Store first."
}

Write-Host "[*] Refreshing winget sources..." -ForegroundColor Cyan
& winget source update | Out-Null

$ToInstall = @()
if ($Essentials) { $ToInstall += $EssentialsList }
if ($Utilities)  { $ToInstall += $UtilitiesList  }

$Failed = @()
foreach ($pkg in $ToInstall) {
    Write-Host ""
    Write-Host "[*] Installing $pkg ..." -ForegroundColor Cyan
    & winget install --id $pkg --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "winget exited with code $LASTEXITCODE for $pkg"
        $Failed += $pkg
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "   Install complete. Restart your terminal" -ForegroundColor Green
Write-Host "   to pick up new shims on PATH."           -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

if ($Failed.Count -gt 0) {
    Write-Host ""
    Write-Warning "Failed packages ($($Failed.Count)):"
    $Failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "Re-run from an elevated prompt if these need admin." -ForegroundColor Yellow
    exit 1
}
