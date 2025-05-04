# PowerShell script to scan my movies folder and all its sub folders to find duplicate movie files.
# Sometimes I have multiple copies of the same movie in the folder with different extensions.
# It will check for files larger than a specified size (default 500MB)
# and will group them by folder name.
# It will then check if there are more than two files in that folder
# that are larger than the specified size.
# If so, it will print the folder name and the names of the files in that folder.
# This is useful for finding duplicate movie files that are larger than a specified size.


param(
    [string]$RootFolder = "G:\Movies",
    [int]$SizeMB = 500
)


$ThresholdBytes = $SizeMB * 1MB

$allFiles = Get-ChildItem -Path $RootFolder -Recurse -File -ErrorAction SilentlyContinue
Write-Host "Total files found: $($allFiles.Count)"

$largeFiles = $allFiles | Where-Object { $_.Length -gt $ThresholdBytes }
Write-Host "Total large files found: $($largeFiles.Count)"

$grouped = $largeFiles | Group-Object -Property DirectoryName
Write-Host "Total directories with at least one large file: $($grouped.Count)"

$found = $false
foreach ($group in $grouped) {
    if ($group.Count -gt 2) {
        $found = $true
        Write-Host ">>> Folder with more than two large files: $($group.Name)"
        foreach ($file in $group.Group) {
            Write-Host "    Large file: $($file.Name) - $([Math]::Round($file.Length / 1MB, 2)) MB"
        }
    }
}

if (-not $found) {
    Write-Host "`nNo folders found with more than two files larger than $SizeMB MB."
}