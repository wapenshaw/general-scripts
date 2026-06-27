<#
.SYNOPSIS
    Moves .bacpac files out of the SQL Server Management Studio Documents folder into a single destination.

.DESCRIPTION
    Scans the default SSMS Documents folder recursively for *.bacpac files and moves each
    one into the destination, creating the destination directory if needed.

    The source and destination paths are hard-coded in the USER CONFIGURATION block - edit to suit.

.EXAMPLE
    PS> pwsh -File .\Move-BacpacFiles.ps1

.NOTES
    No admin required.
#>

# Define source and destination directories
$sourceDir = "E:\OneDrive\Documents\SQL Server Management Studio"
$destDir = "E:\Bacpacs"

# Create destination directory if it does not exist
if (!(Test-Path -Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

# Get all .bacpac files recursively in the source directory
$bacpacFiles = Get-ChildItem -Path $sourceDir -Filter *.bacpac -Recurse

# Move each file to the destination directory
foreach ($file in $bacpacFiles) {
    $targetPath = Join-Path -Path $destDir -ChildPath $file.Name
    Move-Item -Path $file.FullName -Destination $targetPath -Force
    Write-Host "Moved $($file.FullName) to $targetPath"
}