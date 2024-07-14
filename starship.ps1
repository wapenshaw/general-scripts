# Define the source and destination paths
$sourcePath = "starship/pastel-powerline.toml"
$destinationPath = "$HOME/.config/starship.toml"

# Check if the source file exists
if (-Not (Test-Path -Path $sourcePath)) {
    Write-Host "Source file not found: $sourcePath" -ForegroundColor Red
    exit 1
}

# Create the destination directory if it doesn't exist
$destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationPath)
if (-Not (Test-Path -Path $destinationDirectory)) {
    Write-Host "Creating destination directory: $destinationDirectory"
    New-Item -ItemType Directory -Path $destinationDirectory -Force
}

# Copy the file to the destination
Write-Host "Copying file to $destinationPath"
Copy-Item -Path $sourcePath -Destination $destinationPath -Force

Write-Host "File copied successfully."
