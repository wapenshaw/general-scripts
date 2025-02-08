param(
    [string[]]$ExcludePackages = @("Youtube", "Filebot")
)

# Check if running with admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "This script is not running with administrator privileges." -ForegroundColor Yellow
    Write-Host "It's recommended to run this script as an administrator for full functionality." -ForegroundColor Yellow
    $continueAnyway = Read-Host "Do you want to continue anyway? (y/n) [Default: n]"
    if ($continueAnyway.ToLower() -ne "y") {
        Write-Host "Script execution cancelled. Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}

# Ask for interactive mode preference
Write-Host "`nDo you want to be prompted for each package upgrade?" -ForegroundColor Cyan
Write-Host "- Interactive mode (y): You will be asked about each package individually" -ForegroundColor Cyan
Write-Host "- Batch mode (n): You will be asked once for all packages" -ForegroundColor Cyan
$interactiveChoice = Read-Host "Choose mode (y/n) [Default: n]"
$Interactive = $interactiveChoice.ToLower() -eq "y"

# Get the list of upgradable packages
$wingetOutput = winget upgrade

# Convert the output to an array and clean it up
$wingetOutputArray = $wingetOutput -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { 
    $_ -and # Remove empty lines
    $_ -notmatch '^-{2,}$' -and # Remove divider lines
    $_ -notmatch '^\s*[-\\]' -and # Remove lines with just - or \
    $_ -notmatch 'upgrades available' -and # Remove summary line
    $_ -notmatch 'following packages' -and # Remove explicit targeting message
    $_ -notmatch 'package\(s\) have' -and # Remove pin/unknown version messages
    $_ -notmatch 'Using the --include-pinned'     # Remove hint messages
}

# Parse the upgradable packages
$upgradablePackages = @()
$isMainSection = $true
foreach ($line in $wingetOutputArray) {
    # Skip header rows
    if ($line -match '^Name\s+Id\s+Version\s+Available\s+Source') {
        continue
    }
    
    # Check if we've reached the explicit targeting section
    if ($line -match '^Name\s+Id\s+Version\s+Available\s+Source$') {
        $isMainSection = $false
        continue
    }

    if ($line -match '^(.*?)\s{2,}(\S+)\s{2,}(\S+)\s{2,}(\S+)(?:\s{2,}(\S+))?$') {
        $upgradablePackages += [PSCustomObject]@{
            Name             = $matches[1].Trim()
            Id               = $matches[2]
            Version          = $matches[3]
            AvailableVersion = $matches[4]
            Source           = if ($matches[5]) { $matches[5] } else { "Unknown" }
            RequiresExplicit = -not $isMainSection
        }
    }
}

# Separate packages into available and excluded
$availableUpgrades = @()
$excludedUpgrades = @()

foreach ($package in $upgradablePackages) {
    if ($ExcludePackages -contains $package.Name -or $ExcludePackages -contains $package.Id) {
        $excludedUpgrades += $package
    }
    else {
        $availableUpgrades += $package
    }
}

# Print the list of available upgrades
Write-Host "`nThe following packages are available for upgrade:" -ForegroundColor Green
if ($availableUpgrades.Count -eq 0) {
    Write-Host "No packages available for upgrade." -ForegroundColor Green
}
else {
    $availableUpgrades | ForEach-Object {
        $requiresExplicit = if ($_.RequiresExplicit) { " (Requires explicit targeting)" } else { "" }
        Write-Host "$($_.Name) ($($_.Id)) - $($_.Version) -> $($_.AvailableVersion)$requiresExplicit"
    }
}

# Print the list of excluded upgrades
Write-Host "`nThe following packages are excluded from upgrade:" -ForegroundColor DarkCyan
if ($excludedUpgrades.Count -eq 0) {
    Write-Host "No packages excluded from upgrade." -ForegroundColor DarkCyan
}
else {
    $excludedUpgrades | ForEach-Object {
        Write-Host "$($_.Name) ($($_.Id)) - $($_.Version) -> $($_.AvailableVersion)"
    }
}

# Process upgrades
if ($availableUpgrades.Count -gt 0) {
    if ($Interactive) {
        Write-Host "`nInteractive mode: You will be prompted for each package." -ForegroundColor Yellow
        foreach ($package in $availableUpgrades) {
            $explicitNote = if ($package.RequiresExplicit) { " (Requires explicit targeting)" } else { "" }
            $confirmation = Read-Host "`nDo you want to upgrade $($package.Name) from $($package.Version) to $($package.AvailableVersion)$explicitNote? (y/n) [Default: n]"
            if ($confirmation.ToLower() -eq "y") {
                Write-Host "Upgrading $($package.Name)..." -ForegroundColor Magenta
                if ($package.RequiresExplicit) {
                    winget upgrade --id $package.Id --source winget --silent
                }
                else {
                    winget upgrade --id $package.Id --silent
                }
                Write-Host "Upgrade completed for $($package.Name)" -ForegroundColor Green
            }
            else {
                Write-Host "Skipping $($package.Name)" -ForegroundColor Yellow
            }
        }
    }
    else {
        $confirmation = Read-Host "`nDo you want to proceed with upgrading all available packages? (y/n) [Default: n]"
        if ($confirmation.ToLower() -eq "y") {
            foreach ($package in $availableUpgrades) {
                Write-Host "Upgrading $($package.Name)..." -ForegroundColor Magenta
                if ($package.RequiresExplicit) {
                    winget upgrade --id $package.Id --source winget --silent
                }
                else {
                    winget upgrade --id $package.Id --silent
                }
                Write-Host "Upgrade completed for $($package.Name)" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Upgrade cancelled." -ForegroundColor Red
        }
    }
}
else {
    Write-Host "`nNo packages to upgrade." -ForegroundColor DarkCyan
}

Write-Host "`nPress any key to exit..." -ForegroundColor Magenta
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")