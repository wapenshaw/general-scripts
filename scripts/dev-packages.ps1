# 1. Selection Menu
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   DEV PACKAGE PATH REDIRECTION SETUP" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Target Path: Z:\Packages" -ForegroundColor Gray
Write-Host ""
Write-Host "1. USER Level   (Current user only, no Admin required)"
Write-Host "2. SYSTEM Level (All users, REQUIRES Admin privileges)"
Write-Host ""

$choice = Read-Host "Select an option (1 or 2)"

# 2. Scope Logic & Admin Check
if ($choice -eq "2") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "`n[!] ERROR: You must run this script as ADMINISTRATOR to set System-level variables." -ForegroundColor Red
        pause
        return
    }
    $Scope = "Machine"
    Write-Host "`n[i] Setting variables at SYSTEM level..." -ForegroundColor Yellow
} 
elseif ($choice -eq "1") {
    $Scope = "User"
    Write-Host "`n[i] Setting variables at USER level..." -ForegroundColor Yellow
} 
else {
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
    return
}

# 3. Drive Check
$BasePath = "Z:\Packages"
if (!(Test-Path "Z:\")) {
    Write-Host "[!] ERROR: Drive Z: is not detected. Please mount your drive." -ForegroundColor Red
    pause
    return
}

# 4. Define Mappings
$Mappings = @{
    "NUGET_PACKAGES"    = ".nuget"
    "GRADLE_USER_HOME"  = ".gradle"
    "npm_config_cache"  = "npm_cache"
    "PIP_CACHE_DIR"     = "python_cache"
    "CARGO_HOME"        = ".cargo"
    "GOPATH"            = ".go"
    "GOCACHE"           = ".go\cache"
    "MAVEN_OPTS"        = "-Dmaven.repo.local=$BasePath\.m2\repository"
    "YARN_CACHE_FOLDER" = "yarn_cache"
    "GEM_HOME"          = ".gem"
}

# 5. Execution Loop
foreach ($Var in $Mappings.Keys) {
    $SubFolder = $Mappings[$Var]
    $FullValue = if ($Var -eq "MAVEN_OPTS") { $SubFolder } else { Join-Path $BasePath $SubFolder }

    # Create folder if needed
    if ($Var -ne "MAVEN_OPTS" -and !(Test-Path $FullValue)) {
        New-Item -ItemType Directory -Path $FullValue -Force | Out-Null
    }

    # If System scope chosen, clean up User scope to avoid conflicts (Shadowing)
    if ($Scope -eq "Machine") {
        if ([System.Environment]::GetEnvironmentVariable($Var, "User")) {
            [System.Environment]::SetEnvironmentVariable($Var, $null, "User")
            Write-Host "[-] Cleared User-level conflict for $Var" -ForegroundColor Gray
        }
    }

    # Set the variable in the chosen Registry scope
    [System.Environment]::SetEnvironmentVariable($Var, $FullValue, $Scope)
    
    # Update current session so it's usable immediately
    Set-Item -Path "Env:$Var" -Value $FullValue
    Write-Host "[+] Configured $Var" -ForegroundColor Green
}

# 6. Python PATH Handling
Write-Host "`n--- Checking Python PATH ---" -ForegroundColor Cyan
try {
    $pythonPath = py -c "import sys; print(sys.prefix)" -ErrorAction Stop
    $scriptsPath = Join-Path $pythonPath "Scripts"
    $pythonDirs = @($pythonPath, $scriptsPath)

    # Get the correct PATH registry based on scope
    $currentPathValue = [System.Environment]::GetEnvironmentVariable("Path", $Scope)
    $pathList = $currentPathValue -split ';' | Where-Object { $_ }

    $modified = $false
    foreach ($dir in $pythonDirs) {
        if ($pathList -notcontains $dir) {
            $pathList = @($dir) + $pathList # Add to top
            $modified = $true
        }
    }

    if ($modified) {
        [System.Environment]::SetEnvironmentVariable("Path", ($pathList -join ';'), $Scope)
        Write-Host "[+] Python added to $Scope PATH." -ForegroundColor Green
    }
    else {
        Write-Host "[i] Python already exists in $Scope PATH." -ForegroundColor Gray
    }
}
catch {
    Write-Host "[!] Python (py) launcher not found. Skipping PATH setup." -ForegroundColor Yellow
}

# 7. NPM Config Update
if (Get-Command npm -ErrorAction SilentlyContinue) {
    # If scope is system, try to use --global flag
    $npmFlag = if ($Scope -eq "Machine") { "--global" } else { "" }
    npm config set cache "$BasePath\npm_cache" $npmFlag
    Write-Host "[+] npm cache config updated." -ForegroundColor Yellow
}

Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "Please RESTART your terminal/IDE or REBOOT to apply." -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan