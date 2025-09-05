<#
.SYNOPSIS
    Traverses a source directory recursively and copies all found files into a 
    single destination folder, flattening the directory structure.

.DESCRIPTION
    This script finds every file within the specified $SourceFolder and all its
    subdirectories. It then copies each file to a single $DestinationFolder.

    It does NOT preserve the original folder structure in the destination.

    To prevent data loss from files with the same name in different source 
    subdirectories, the script checks if a file already exists in the destination.
    If it does, it renames the new file by appending a number, e.g.,
    'document.txt' becomes 'document(1).txt'.

.PARAMETER SourceFolder
    The full path to the root directory you want to search for files.
    Example: "C:\Users\YourUser\Documents\Projects"

.PARAMETER DestinationFolder
    The full path to the single folder where all files will be copied.
    This folder will be created if it does not exist.
    Example: "C:\Temp\AllFilesCopiedHere"
#>

#requires -Version 3.0

#===========================================================================
#                            USER CONFIGURATION
#===========================================================================

# The folder you want to copy files FROM (including all its subfolders)
$SourceFolder = "Z:\SigmaWays\Documents"

# The single folder you want to copy all files TO
$DestinationFolder = "Z:\SigmaWays\Merge"

#===========================================================================
#                         SCRIPT LOGIC (No need to edit below)
#===========================================================================

# --- 1. Validate Paths and Setup ---

# Check if the source folder exists
if (-not (Test-Path -Path $SourceFolder -PathType Container)) {
    Write-Error "Source folder not found: '$SourceFolder'. Please check the path and try again."
    # Exit the script because we have nothing to copy from.
    exit
}

# Check if the destination folder exists. If not, create it.
if (-not (Test-Path -Path $DestinationFolder -PathType Container)) {
    Write-Host "Destination folder not found. Creating it now: '$DestinationFolder'" -ForegroundColor Yellow
    New-Item -Path $DestinationFolder -ItemType Directory | Out-Null
}

Write-Host "Starting file copy process..."
Write-Host "Source:      $SourceFolder"
Write-Host "Destination: $DestinationFolder"
Write-Host "--------------------------------------------------"

# --- 2. Get All Files and Copy Them ---

# Get all file objects from the source folder and all its subfolders recursively
$allFiles = Get-ChildItem -Path $SourceFolder -Recurse -File

# Loop through each file found
foreach ($file in $allFiles) {
    # Define the intended destination path for the current file
    $targetPath = Join-Path -Path $DestinationFolder -ChildPath $file.Name

    # Check if a file with the same name already exists in the destination
    if (Test-Path -Path $targetPath) {
        # If it exists, we need to find a new name
        Write-Host "  [!] Filename conflict: '$($file.Name)' already exists." -ForegroundColor Yellow
        $counter = 1
        # Get the filename without the extension and the extension itself
        $fileNameWithoutExt = $file.BaseName
        $fileExtension = $file.Extension # This includes the dot, e.g., ".txt"
        
        # Loop until we find a name that is not taken
        do {
            $newFileName = "{0}({1}){2}" -f $fileNameWithoutExt, $counter, $fileExtension
            $newTargetPath = Join-Path -Path $DestinationFolder -ChildPath $newFileName
            $counter++
        } while (Test-Path -Path $newTargetPath)

        Write-Host "      -> Renaming and copying to '$newFileName'" -ForegroundColor Green
        Copy-Item -Path $file.FullName -Destination $newTargetPath
    }
    else {
        # If the file does not exist, just copy it
        Write-Host "  -> Copying '$($file.Name)'" -ForegroundColor Cyan
        Copy-Item -Path $file.FullName -Destination $targetPath
    }
}

Write-Host "--------------------------------------------------"
Write-Host "Process complete. All files have been copied." -ForegroundColor Green