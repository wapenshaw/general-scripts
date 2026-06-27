<#
.SYNOPSIS
    Imports .reg files from registry-tweaks\dos (apply) or registry-tweaks\undos (revert).

.DESCRIPTION
    Prompts the user for "apply" or "undo" and then runs `reg.exe import` against every
    .reg file in the matching subfolder of the sibling ..\registry-tweaks\ directory.

.EXAMPLE
    PS> pwsh -File .\Invoke-RegistryTweaks.ps1

.NOTES
    Run from an elevated PowerShell session.
#>

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "You need to run this script as an administrator."
    exit
}

# Ask the user whether to apply or undo the registry tweaks
$action = Read-Host "Do you want to apply or undo the registry tweaks? (Enter 'apply' or 'undo')"

# Set the path based on the user's choice
$registryTweaksRoot = Join-Path $PSScriptRoot "..\..\registry-tweaks"
if ($action -eq 'apply') {
    $regFilesPath = Join-Path $registryTweaksRoot "dos"
}
elseif ($action -eq 'undo') {
    $regFilesPath = Join-Path $registryTweaksRoot "undos"
}
else {
    Write-Output "Invalid input. Please enter 'apply' or 'undo'."
    exit
}

# Get all .reg files in the specified folder
if (Test-Path $regFilesPath) {
    $regFiles = Get-ChildItem -Path $regFilesPath -Filter *.reg

    foreach ($regFile in $regFiles) {
        # Import the .reg file into the system registry
        Write-Host "Importing $($regFile.Name)..." -ForegroundColor Cyan
        Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$($regFile.FullName)`"" -Wait -NoNewWindow
    }

    Write-Output "All .reg files have been processed."
}
else {
    Write-Error "Registry tweaks directory not found: $regFilesPath"
}