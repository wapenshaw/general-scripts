# Function to check if winget is installed
function Test-Winget {
    try {
        winget --version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}

# Function to install a font
function Install-Font {  
    param  
    (  
        [System.IO.FileInfo]$fontFile  
    )  
    try {
        $fontName = $fontFile.Name
        switch ($fontFile.Extension) {  
            ".ttf" { $fontName = "$fontName (TrueType)" }  
            ".otf" { $fontName = "$fontName (OpenType)" }  
        }
        Write-Host "Installing font: $fontFile with font name '$fontName'"
        If (!(Test-Path ("$($env:windir)\Fonts\" + $fontFile.Name))) {  
            Write-Host "Copying font: $fontFile"
            Copy-Item -Path $fontFile.FullName -Destination ("$($env:windir)\Fonts\" + $fontFile.Name) -Force 
        }
        else {  
            Write-Host "Font already exists: $fontFile" 
        }
        If (!(Get-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue)) {  
            Write-Host "Registering font: $fontFile"
            New-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value $fontFile.Name -Force -ErrorAction SilentlyContinue | Out-Null  
        }
        else {  
            Write-Host "Font already registered: $fontFile" 
        }
    }
    catch {            
        Write-Host "Error installing font: $fontFile. " $_.exception.message
    }
}

# Function to install fonts from a folder
function Install-Fonts {
    param (
        [string[]]$fontFolders
    )
    
    foreach ($folder in $fontFolders) {
        if (Test-Path -Path $folder) {
            Get-ChildItem -Path $folder -Include *.ttf, *.otf -Recurse | ForEach-Object {
                Install-Font -fontFile $_
            }
        }
        else {
            Write-Host "Font folder not found: $folder" -ForegroundColor Yellow
        }
    }
}

# Check if winget is installed
if (-Not (Test-Winget)) {
    Write-Host "winget is not installed." -ForegroundColor Yellow
    $installWinget = Read-Host "Do you want to install winget? (y/n) [Default: n]"
    if ($installWinget.ToLower() -ne "y") {
        Write-Host "winget installation is required to proceed. Exiting script." -ForegroundColor Red
        exit 1
    }
    else {
        # Open the browser to winget installation page
        Write-Host "Please install winget from the Microsoft Store or https://aka.ms/getwinget"
        Start-Process "https://aka.ms/getwinget"
        Write-Host "Press any key after installing winget to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if (-Not (Test-Winget)) {
            Write-Host "winget is still not installed. Exiting script." -ForegroundColor Red
            exit 1
        }
    }
}

# Install Starship using winget
Write-Host "Installing Starship using winget..."
winget install --id Starship.Starship -e

# Define the path to the source file
$sourceProfile = "./my-profile.ps1"

# Get the path to the current PowerShell profile file
$currentProfile = $PROFILE

# Check if the source file exists
if (-Not (Test-Path -Path $sourceProfile)) {
    Write-Host "Source profile file not found: $sourceProfile" -ForegroundColor Red
    exit 1
}

# Ensure the directory for the current profile exists
$currentProfileDirectory = [System.IO.Path]::GetDirectoryName($currentProfile)
if (-Not (Test-Path -Path $currentProfileDirectory)) {
    Write-Host "Creating directory for the current profile: $currentProfileDirectory"
    New-Item -ItemType Directory -Path $currentProfileDirectory -Force
}

# Overwrite the current profile with the contents of the source profile
Write-Host "Overwriting $currentProfile with the contents of $sourceProfile"
Get-Content -Path $sourceProfile | Set-Content -Path $currentProfile

Write-Host "Profile updated successfully."

# Install fonts from specified folders
$fontFolders = @("fonts/nerd-fonts", "fonts/coding-fonts")
Write-Host "Installing fonts from the specified folders..."
Install-Fonts -fontFolders $fontFolders

Write-Host "Script execution completed successfully."

# Execute starship.ps1
Write-Host "Setting up starship" -ForegroundColor DarkCyan
& ".\starship.ps1"