$ErrorActionPreference = "Stop"

# --- Configuration ---
$SourceRoot      = $PSScriptRoot
$SourceProfile   = Join-Path $SourceRoot "my-profile.ps1"
$SourceFunctions = Join-Path $SourceRoot "functions"
$SourceStarship  = Join-Path $SourceRoot "starship.ps1"

# Destination config directory (Using XDG-like structure)
$InstallDir      = Join-Path $HOME ".config\powershell"
$DestFunctions   = Join-Path $InstallDir "functions"
$DestProfile     = Join-Path $InstallDir "user_profile.ps1"

# --- 1. Validate Source ---
if (-not (Test-Path $SourceProfile)) {
    Write-Error "Source profile not found: $SourceProfile"
}

# --- 2. Prepare Destination ---
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Write-Host "[+] Created config dir: $InstallDir" -ForegroundColor Cyan
}

if (-not (Test-Path $DestFunctions)) {
    New-Item -ItemType Directory -Path $DestFunctions -Force | Out-Null
    Write-Host "[+] Created functions dir: $DestFunctions" -ForegroundColor Cyan
}

# --- 3. Install Files ---
Write-Host "[*] Installing profile scripts..." -ForegroundColor Yellow

# Copy main profile
Copy-Item -Path $SourceProfile -Destination $DestProfile -Force
Write-Host "    - Copied user_profile.ps1" -ForegroundColor Gray

# Copy functions
$FunctionFiles = Get-ChildItem -Path $SourceFunctions -Filter "*.ps1"
foreach ($File in $FunctionFiles) {
    Copy-Item -Path $File.FullName -Destination $DestFunctions -Force
    Write-Host "    - Copied function: $($File.Name)" -ForegroundColor Gray
}

# --- 4. Update PowerShell $PROFILE ---
# Ensure parent dir of $PROFILE exists
$ProfileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
}

# Create the loader script content
$LoaderScript = @"
# --- Generated Loader by install-profile.ps1 ---
`$ConfigDir = "$InstallDir"
`$UserProfile = Join-Path `$ConfigDir "user_profile.ps1"

# 1. Load Main Profile
if (Test-Path `$UserProfile) {
    . `$UserProfile
}

# 2. Load Functions
if (Test-Path (Join-Path `$ConfigDir "functions")) {
    Get-ChildItem -Path (Join-Path `$ConfigDir "functions") -Filter "*.ps1" | ForEach-Object {
        . `$_.FullName
    }
}
"@

# Write to $PROFILE
Set-Content -Path $PROFILE -Value $LoaderScript -Force
Write-Host "[+] Updated `$PROFILE at: $PROFILE" -ForegroundColor Green

# --- 5. Run Starship Setup ---
if (Test-Path $SourceStarship) {
    Write-Host "`n[*] Running Starship setup..." -ForegroundColor Yellow
    try {
        & $SourceStarship
    }
    catch {
        Write-Warning "Starship setup failed: $_"
    }
}
else {
    Write-Warning "Starship script not found at $SourceStarship"
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "   PROFILE INSTALLATION COMPLETE" -ForegroundColor Green
Write-Host "   Restart PowerShell to apply changes." -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan
