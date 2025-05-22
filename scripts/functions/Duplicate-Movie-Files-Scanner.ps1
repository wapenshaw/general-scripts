# PowerShell script to scan my movies folder and all its sub folders to find duplicate movie files.
# Sometimes I have multiple copies of the same movie in the folder with different extensions.
# It will check for files larger than a specified size (default 500MB)
# and will group them by folder name.
# It will then check if there are more than two files in that folder
# that are larger than the specified size.
# If so, it will print the folder name and the names of the files in that folder.
# This is useful for finding duplicate movie files that are larger than a specified size.

function Find-DuplicateMovieFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RootFolder = "G:\Movies",

        [Parameter(Mandatory = $false)]
        [int]$SizeMB = 500
    )

    Begin {
        Write-Host "Scanning for duplicate movie files larger than $SizeMB MB in '$RootFolder'..."
        $ThresholdBytes = $SizeMB * 1MB
    }

    Process {
        try {
            $allFiles = Get-ChildItem -Path $RootFolder -Recurse -File -ErrorAction Stop
            Write-Host "Total files found: $($allFiles.Count)"

            $largeFiles = $allFiles | Where-Object { $_.Length -gt $ThresholdBytes }
            Write-Host "Total large files found: $($largeFiles.Count)"

            if ($largeFiles.Count -eq 0) {
                Write-Host "No files found larger than $SizeMB MB."
                return
            }

            $grouped = $largeFiles | Group-Object -Property DirectoryName
            Write-Host "Total directories with at least one large file: $($grouped.Count)"

            $found = $false
            foreach ($group in $grouped) {
                # Check if there are more than ONE file, indicating potential duplicates
                if ($group.Count -gt 1) {
                    $found = $true
                    Write-Host "`n>>> Potential duplicates found in folder: $($group.Name)"
                    foreach ($file in $group.Group) {
                        Write-Host "    - $($file.Name) ($([Math]::Round($file.Length / 1MB, 2)) MB)"
                    }
                }
            }

            if (-not $found) {
                Write-Host "`nNo folders found with more than one file larger than $SizeMB MB."
            }
        }
        catch {
            Write-Error "An error occurred: $($_.Exception.Message)"
        }
    }

    End {
        Write-Host "`nScan complete."
    }
}

# Example usage (optional, can be removed if you source this file):
# Find-DuplicateMovieFiles -RootFolder "Path\To\Your\Movies" -SizeMB 700

Set-Alias dupedelete Find-DuplicateMovieFiles