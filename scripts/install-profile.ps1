# Define the source and destination paths
$sourceProfilePath = "./my-profile.ps1"
$functionsFolder = "./functions"
$destinationProfilePath = "$PROFILE"
$starshipScriptPath = "./starship.ps1"

# Check if the source profile file exists
if (-Not (Test-Path -Path $sourceProfilePath)) {
    Write-Host "Source profile file not found: $sourceProfilePath" -ForegroundColor Red
    exit 1
}

# Ensure the directory for the destination profile exists
$destinationProfileDirectory = [System.IO.Path]::GetDirectoryName($destinationProfilePath)
if (-Not (Test-Path -Path $destinationProfileDirectory)) {
    Write-Host "Creating directory for the destination profile: $destinationProfileDirectory"
    New-Item -ItemType Directory -Path $destinationProfileDirectory -Force
}

# Read the content of the source profile file
$sourceProfileContent = Get-Content -Path $sourceProfilePath

# Get all .ps1 files in the functions folder
$functionFiles = Get-ChildItem -Path $functionsFolder -Filter *.ps1
Write-Host("Found " + $functionFiles.Count + " function files")
# Read the content of all function files and merge them into one array
$mergedContent = @($sourceProfileContent)
foreach ($file in $functionFiles) {
    $mergedContent += Get-Content -Path $file.FullName
    Write-Host("Merged " + $file.Name)
}

# Write the merged content to the destination profile file
$mergedContent | Set-Content -Path $destinationProfilePath

# Execute starship.ps1
Write-Host "Executing starship.ps1 script..."
try {
    & $starshipScriptPath
    Write-Host "starship.ps1 executed successfully."
}
catch {
    Write-Host "Error executing starship.ps1: $_" -ForegroundColor Yellow
}

Write-Host "Profile script updated successfully: $destinationProfilePath"
