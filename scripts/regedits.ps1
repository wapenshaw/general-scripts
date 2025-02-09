# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Output "You need to run this script as an administrator."
    exit
}

# Ask the user whether to apply or undo the registry tweaks
$action = Read-Host "Do you want to apply or undo the registry tweaks? (Enter 'apply' or 'undo')"

# Set the path based on the user's choice
if ($action -eq 'apply') {
    $regFilesPath = ".\registry-tweaks\dos\"
}
elseif ($action -eq 'undo') {
    $regFilesPath = ".\registry-tweaks\undos\"
}
else {
    Write-Output "Invalid input. Please enter 'apply' or 'undo'."
    exit
}

# Get all .reg files in the specified folder
$regFiles = Get-ChildItem -Path $regFilesPath -Filter *.reg

foreach ($regFile in $regFiles) {
    # Import the .reg file into the system registry
    Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$($regFile.FullName)`"" -Wait -NoNewWindow
}

Write-Output "All .reg files have been merged into the system registry."