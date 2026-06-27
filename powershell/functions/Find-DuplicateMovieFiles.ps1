<#
.SYNOPSIS
    Finds duplicate movie files (same folder, > -SizeMB) in a movies directory.

.DESCRIPTION
    Walks -RootFolder recursively and groups files larger than -SizeMB by their
    parent folder. Any folder containing more than one such file is reported as a
    potential duplicate (different extensions of the same movie are common).

.PARAMETER RootFolder
    Movies root. Default: G:\Movies.
.PARAMETER SizeMB
    Minimum file size in MB to consider. Default: 500.

.EXAMPLE
    PS> Find-DuplicateMovieFiles -RootFolder 'G:\Movies' -SizeMB 700
    PS> dupedelete     # alias uses the defaults

.NOTES
    No admin required. Alias: dupedelete.
#>

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