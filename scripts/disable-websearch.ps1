# Registry paths for the Group Policy settings
$policies = @{
    "NoWebSearch"  = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "DisableWebSearch"
        Type        = "DWord"
        Value       = 1
        Description = "Do not allow web search"
    }
    "NoSearchWeb"  = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "ConnectedSearchUseWeb"
        Type        = "DWord"
        Value       = 0
        Description = "Don't search the web or display web results in Search"
    }
    "NoMeteredWeb" = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "ConnectedSearchUseWebOverMeteredConnections"
        Type        = "DWord"
        Value       = 0
        Description = "Don't search the web or display web results in Search over metered connections"
    }
}

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Create registry path if it doesn't exist
foreach ($policy in $policies.Values) {
    if (-not (Test-Path $policy.Path)) {
        $confirm = Read-Host "Registry path $($policy.Path) does not exist. Create it? (Y/N)"
        if ($confirm -eq 'Y') {
            New-Item -Path $policy.Path -Force | Out-Null
        }
        else {
            Write-Host "Skipping policy: $($policy.Description)" -ForegroundColor Yellow
            continue
        }
    }
}

# Apply each policy
foreach ($policy in $policies.Values) {
    $confirm = Read-Host "Do you want to enable '$($policy.Description)'? (Y/N)"
    if ($confirm -eq 'Y') {
        try {
            Set-ItemProperty -Path $policy.Path -Name $policy.Name -Type $policy.Type -Value $policy.Value -Force
            Write-Host "Successfully applied: $($policy.Description)" -ForegroundColor Green
        }
        catch {
            Write-Host "Error applying: $($policy.Description)" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    }
    else {
        Write-Host "Skipped: $($policy.Description)" -ForegroundColor Yellow
    }
}

Write-Host "`nAll policies have been processed. Please restart your computer for changes to take effect." -ForegroundColor Cyan