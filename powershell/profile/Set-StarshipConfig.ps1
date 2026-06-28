<#
.SYNOPSIS
    Interactive picker for a starship.toml from the repo's starship\ directory, with optional non-interactive theme selection.

.DESCRIPTION
    Lists every file in the repo's starship\ directory and copies the chosen one to
    $HOME\.config\starship.toml, creating the directory if needed.

    If -Theme is supplied, or $env:PS_STARSHIP_THEME is set, the picker is skipped
    and the named theme is installed directly (after validating the file exists).

.EXAMPLE
    PS> pwsh -File .\Set-StarshipConfig.ps1

.EXAMPLE
    PS> pwsh -File .\Set-StarshipConfig.ps1 -Theme nordic

.EXAMPLE
    PS> $env:PS_STARSHIP_THEME = 'nova'; pwsh -File .\Set-StarshipConfig.ps1

.NOTES
    No admin required. Run by Install-Profile.ps1 automatically as part of profile setup.
#>

[CmdletBinding()]
param(
    [string]$Theme
)

# Define the source directory
$sourceDirectory = Join-Path $PSScriptRoot "../../starship"

# Get all files in the source directory
$files = Get-ChildItem -Path $sourceDirectory -File

# Check if there are any files to select from
if ($files.Count -eq 0) {
    Write-Host "No files found in $sourceDirectory." -ForegroundColor Red
    exit 1
}

# Resolve the theme: explicit param wins, then env var, otherwise prompt interactively.
if (-not $Theme -and $env:PS_STARSHIP_THEME) {
    $Theme = $env:PS_STARSHIP_THEME
}

if ($Theme) {
    # Match on basename (e.g. "nordic") or full filename (e.g. "nordic.toml").
    $resolved = $files | Where-Object { $_.BaseName -eq $Theme -or $_.Name -eq $Theme } | Select-Object -First 1
    if (-not $resolved) {
        Write-Host "Theme '$Theme' not found in $sourceDirectory. Available: $($files.Name -join ', ')" -ForegroundColor Red
        exit 1
    }
    $sourceFile = $resolved.FullName
    $themeName  = $resolved.Name
}
else {
    # Display menu to select a file
    Write-Host "Select a file to copy to $HOME/.config/starship.toml:`n"
    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-Host "$($i + 1). $($files[$i].Name)" -ForegroundColor Cyan
    }

    # Prompt for user input
    $selection = Read-Host "Enter the number of the file to copy (1-$($files.Count))"

    # Validate user input
    if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $files.Count) {
        $sourceFile = $files[$selection - 1].FullName
        $themeName  = $files[$selection - 1].Name
    }
    else {
        Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
        exit 1
    }
}

# Define the destination path
$destinationPath = "$HOME/.config/starship.toml"

# Create the destination directory if it doesn't exist
$destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationPath)
if (-Not (Test-Path -Path $destinationDirectory)) {
    Write-Host "Creating destination directory: $destinationDirectory" -ForegroundColor DarkYellow
    New-Item -ItemType Directory -Path $destinationDirectory -Force
}

# Copy the file to the destination
Write-Host "Copying $themeName to $destinationPath" -ForegroundColor DarkYellow
Copy-Item -Path $sourceFile -Destination $destinationPath -Force

Write-Host "File copied successfully." -ForegroundColor Green
