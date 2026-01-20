<#
.SYNOPSIS
    Configures Windows registry settings to speed up shutdown and auto-end hung tasks.
    
.DESCRIPTION
    Based on the Tom's Hardware article "Windows 11 won't let you shut down? Change this setting right away!",
    this script modifies registry keys to:
    https://www.tomshardware.com/software/windows/windows-11-wont-let-you-shut-down-change-this-setting-right-away
    1. Automatically end tasks that are preventing shutdown.
    2. Reduce the timeout wait for killing apps (WaitToKillAppTimeout).
    3. Reduce the timeout wait for hung apps (HungAppTimeout).
    4. Reduce the timeout wait for killing services (WaitToKillServiceTimeout).

    Registry Keys Modified:
    - HKCU\Control Panel\Desktop\AutoEndTasks
    - HKCU\Control Panel\Desktop\WaitToKillAppTimeout
    - HKCU\Control Panel\Desktop\HungAppTimeout
    - HKLM\SYSTEM\CurrentControlSet\Control\WaitToKillServiceTimeout
#>

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges to modify HKLM registry keys." -ForegroundColor Red
    Write-Host "Please run this script as Administrator." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Define the registry settings to apply
$settings = @(
    @{
        Path        = "HKCU:\Control Panel\Desktop"
        Name        = "AutoEndTasks"
        Value       = "1"
        Type        = "String"
        Description = "Enable AutoEndTasks (Automatically close open apps on shutdown)"
    },
    @{
        Path        = "HKCU:\Control Panel\Desktop"
        Name        = "WaitToKillAppTimeout"
        Value       = "2000"
        Type        = "String"
        Description = "Set WaitToKillAppTimeout to 2000ms (2 seconds)"
    },
    @{
        Path        = "HKCU:\Control Panel\Desktop"
        Name        = "HungAppTimeout"
        Value       = "2000"
        Type        = "String"
        Description = "Set HungAppTimeout to 2000ms (2 seconds)"
    },
    @{
        Path        = "HKLM:\SYSTEM\CurrentControlSet\Control"
        Name        = "WaitToKillServiceTimeout"
        Value       = "2000"
        Type        = "String"
        Description = "Set WaitToKillServiceTimeout to 2000ms (2 seconds)"
    }
)

Write-Host "--- Windows Shutdown Optimization ---" -ForegroundColor Cyan
Write-Host "This script will apply registry tweaks to speed up the shutdown process." -ForegroundColor Gray
Write-Host "Note: HKCU settings apply to the current user account running this script." -ForegroundColor DarkGray
Write-Host ""

$confirm = Read-Host "Do you want to apply these settings? (y/n)"
if ($confirm.ToLower() -ne 'y') {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

foreach ($setting in $settings) {
    try {
        if (-not (Test-Path $setting.Path)) {
            New-Item -Path $setting.Path -Force | Out-Null
        }

        $current = Get-ItemProperty -Path $setting.Path -Name $setting.Name -ErrorAction SilentlyContinue
        if ($null -eq $current) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force -ErrorAction Stop
            Write-Host "Applied: $($setting.Description)" -ForegroundColor Green
        }
        elseif ("$($current.$($setting.Name))" -ne "$($setting.Value)") {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.Value -Type $setting.Type -Force -ErrorAction Stop
            Write-Host "Updated: $($setting.Description)" -ForegroundColor Green
        }
        else {
            Write-Host "Skipped: $($setting.Description) (Already set)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to apply: $($setting.Description)" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nDone. Please restart your computer for changes to take full effect." -ForegroundColor Cyan
