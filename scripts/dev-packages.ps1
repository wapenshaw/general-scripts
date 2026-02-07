# 1. Setup & Functions
$ErrorActionPreference = "Stop"

function Test-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   DEV PACKAGE PATH REDIRECTION SETUP" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Target Path: Z:\Packages" -ForegroundColor Gray
Write-Host ""
Write-Host "1. USER Level   (Current user only, no Admin required)"
Write-Host "2. SYSTEM Level (All users, REQUIRES Admin privileges)"
Write-Host ""

$choice = Read-Host "Select an option (1 or 2)"

# 2. Scope Logic
switch ($choice) {
    "1" {
        $Scope = "User"
        Write-Host "`n[i] Setting variables at USER level..." -ForegroundColor Yellow
    }
    "2" {
        if (-not (Test-Admin)) {
            Write-Host "`n[!] ERROR: You must run this script as ADMINISTRATOR to set System-level variables." -ForegroundColor Red
            pause
            exit
        }
        $Scope = "Machine"
        Write-Host "`n[i] Setting variables at SYSTEM level..." -ForegroundColor Yellow
    }
    Default {
        Write-Host "Invalid selection. Exiting." -ForegroundColor Red
        exit
    }
}

# 3. Drive Check
$BasePath = "Z:\Packages"
if (!(Test-Path "Z:\")) {
    Write-Host "[!] ERROR: Drive Z: is not detected. Please mount your drive." -ForegroundColor Red
    pause
    exit
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
    "YARN_CACHE_FOLDER" = "yarn_cache"
    "GEM_HOME"          = ".gem"
}

# 5. Apply Environment Variables
foreach ($Var in $Mappings.Keys) {
    $SubFolder = $Mappings[$Var]
    $FullValue = Join-Path $BasePath $SubFolder

    # Create directory
    if (-not (Test-Path $FullValue)) {
        New-Item -ItemType Directory -Path $FullValue -Force | Out-Null
    }

    # Clean up User scope if switching to Machine scope
    if ($Scope -eq "Machine" -and [System.Environment]::GetEnvironmentVariable($Var, "User")) {
        [System.Environment]::SetEnvironmentVariable($Var, $null, "User")
        Write-Host "[-] Cleared User-level conflict for $Var" -ForegroundColor Gray
    }

    # Set variable
    [System.Environment]::SetEnvironmentVariable($Var, $FullValue, $Scope)
    Set-Item -Path "Env:$Var" -Value $FullValue
    Write-Host "[+] Configured $Var" -ForegroundColor Green
}

# Handle Special Case: MAVEN_OPTS (It's an argument string, not a path)
$MavenRepo = Join-Path $BasePath ".m2\repository"
$MavenOpts = "-Dmaven.repo.local=$MavenRepo"
[System.Environment]::SetEnvironmentVariable("MAVEN_OPTS", $MavenOpts, $Scope)
Set-Item -Path "Env:MAVEN_OPTS" -Value $MavenOpts
Write-Host "[+] Configured MAVEN_OPTS" -ForegroundColor Green

# 6. Python PATH Handling
Write-Host "`n--- Checking Python PATH ---" -ForegroundColor Cyan
if (Get-Command py -ErrorAction SilentlyContinue) {
    try {
        $pythonPath = py -c "import sys; print(sys.prefix)"
        $scriptsPath = Join-Path $pythonPath "Scripts"
        $pythonDirs = @($pythonPath, $scriptsPath)

        $currentPathValue = [System.Environment]::GetEnvironmentVariable("Path", $Scope)
        # Split by semicolon, remove empty entries
        $pathList = ($currentPathValue -split ';').Where({$_})
        
        $modified = $false
        foreach ($dir in $pythonDirs) {
            if ($pathList -notcontains $dir) {
                $pathList = @($dir) + $pathList # Prepend
                $modified = $true
            }
        }

        if ($modified) {
            [System.Environment]::SetEnvironmentVariable("Path", ($pathList -join ';'), $Scope)
            Write-Host "[+] Python added to $Scope PATH." -ForegroundColor Green
        }
        else {
            Write-Host "[i] Python already in $Scope PATH." -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Failed to determine Python path: $_"
    }
}
else {
    Write-Host "[!] Python (py) launcher not found. Skipping PATH setup." -ForegroundColor Yellow
}

# 7. NPM Config Update
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmFlag = if ($Scope -eq "Machine") { "--global" } else { "" }
    # Use Invoke-Expression or direct call, direct call is safer if arguments are simple
    # npm config set cache "$BasePath\npm_cache" $npmFlag 
    # PowerShell parsing can be tricky with flags, so explicit string arguments help
    if ($npmFlag) {
        npm config set cache "$BasePath\npm_cache" --global
    } else {
        npm config set cache "$BasePath\npm_cache"
    }
    Write-Host "[+] npm cache config updated." -ForegroundColor Yellow
}

Write-Host "`n==============================================" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE!" -ForegroundColor Green
Write-Host "Please RESTART your terminal/IDE or REBOOT to apply." -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan