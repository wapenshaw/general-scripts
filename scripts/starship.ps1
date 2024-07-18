# Define the source directory
$sourceDirectory = "../starship"

# Get all files in the source directory
$files = Get-ChildItem -Path $sourceDirectory -File

# Check if there are any files to select from
if ($files.Count -eq 0) {
    Write-Host "No files found in $sourceDirectory." -ForegroundColor Red
    exit 1
}

# Display menu to select a file
Write-Host "Select a file to copy to $HOME/.config/starship.toml:`n"
for ($i = 0; $i -lt $files.Count; $i++) {
    Write-Host "$($i + 1). $($files[$i].Name)" -ForegroundColor Cyan
}

# Prompt for user input
$selection = Read-Host "Enter the number of the file to copy (1-$($files.Count))"

# Validate user input
if ($selection -match '^\d+$' -and $selection -ge 1 -and $selection -le $files.Count) {
    # Define the chosen source file
    $sourceFile = $files[$selection - 1].FullName

    # Define the destination path
    $destinationPath = "$HOME/.config/starship.toml"

    # Create the destination directory if it doesn't exist
    $destinationDirectory = [System.IO.Path]::GetDirectoryName($destinationPath)
    if (-Not (Test-Path -Path $destinationDirectory)) {
        Write-Host "Creating destination directory: $destinationDirectory" -ForegroundColor DarkYellow
        New-Item -ItemType Directory -Path $destinationDirectory -Force
    }

    # Copy the file to the destination
    Write-Host "Copying $($files[$selection - 1].Name) to $destinationPath" -ForegroundColor DarkYellow
    Copy-Item -Path $sourceFile -Destination $destinationPath -Force

    Write-Host "File copied successfully." -ForegroundColor Green
}
else {
    Write-Host "Invalid selection. Please enter a valid number." -ForegroundColor Red
}
