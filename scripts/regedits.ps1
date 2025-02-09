$regFilesPath = "Z:\registry-tweaks"

# Get all .reg files in the specified folder
$regFiles = Get-ChildItem -Path $regFilesPath -Filter *.reg

foreach ($regFile in $regFiles) {
    # Import the .reg file into the system registry
    Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$($regFile.FullName)`"" -Wait -NoNewWindow
}

Write-Output "All .reg files have been merged into the system registry."
