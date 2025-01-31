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

# List of package names to exclude
$excludePackages = @("Youtube", "Filebot")

# Get the list of upgradable packages
$wingetOutput = winget upgrade

# Find the line that starts the actual package list
$startIndex = ($wingetOutput | Select-String -Pattern "^Name").LineNumber

# Parse the upgradable packages
$upgradablePackages = $wingetOutput[$startIndex..($wingetOutput.Length - 1)] | ForEach-Object {
    if ($_ -match '^(.*?)\s{2,}(\S+)\s{2,}(\S+)\s{2,}(\S+)(?:\s{2,}(\S+))?$') {
        [PSCustomObject]@{
            Name             = $matches[1].Trim()
            Id               = $matches[2]
            Version          = $matches[3]
            AvailableVersion = $matches[4]
            Source           = if ($matches[5]) { $matches[5] } else { "Unknown" }
        }
    }
} | Where-Object { $_.Name -ne "Name" -and $_.Id -ne "Id" }  # Exclude the header row

# Separate packages into available and excluded
$availableUpgrades = @()
$excludedUpgrades = @()

foreach ($package in $upgradablePackages) {
    if ($excludePackages -contains $package.Name -or $excludePackages -contains $package.Id) {
        $excludedUpgrades += $package
    }
    else {
        $availableUpgrades += $package
    }
}

# Print the list of available upgrades
Write-Host "The following packages are available for upgrade:"  -ForegroundColor Green
if ($availableUpgrades.Count -eq 0) {
    Write-Host "No packages available for upgrade."  -ForegroundColor Green
}
else {
    $availableUpgrades | ForEach-Object {
        Write-Host "$($_.Name) ($($_.Id)) - $($_.Version) -> $($_.AvailableVersion)"
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

# Prompt for confirmation if there are available upgrades
if ($availableUpgrades.Count -gt 0) {
    $confirmation = Read-Host "`nDo you want to proceed with the upgrade of available packages? (y/n) [Default: n]"
    if ($confirmation.ToLower() -eq "y") {
        # Run upgrades
        foreach ($package in $availableUpgrades) {
            Write-Host "Upgrading $($package.Name)..." -ForegroundColor Magenta
            winget upgrade --id $package.Id --silent
        }
    }
    else {
        Write-Host "Upgrade cancelled." -ForegroundColor Red
    }
}
else {
    Write-Host "`nNo packages to upgrade." -ForegroundColor DarkCyan
}

Write-Host "Press any key to exit..." -ForegroundColor Magenta
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")