# Registry paths for the Group Policy settings
$policies = @{
    "NoWebSearch"  = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "DisableWebSearch"
        Description = "Do not allow web search"
    }
    "NoSearchWeb"  = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "ConnectedSearchUseWeb"
        Description = "Don't search the web or display web results in Search"
    }
    "NoMeteredWeb" = @{
        Path        = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
        Name        = "ConnectedSearchUseWebOverMeteredConnections"
        Description = "Don't search the web or display web results in Search over metered connections"
    }
}

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrative privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

# Remove each policy
foreach ($policy in $policies.Values) {
    if (Test-Path $policy.Path) {
        $confirm = Read-Host "Do you want to remove '$($policy.Description)'? (Y/N)"
        if ($confirm -eq 'Y') {
            try {
                Remove-ItemProperty -Path $policy.Path -Name $policy.Name -Force -ErrorAction SilentlyContinue
                Write-Host "Successfully removed: $($policy.Description)" -ForegroundColor Green
            }
            catch {
                Write-Host "Error removing: $($policy.Description)" -ForegroundColor Red
                Write-Host $_.Exception.Message
            }
        }
        else {
            Write-Host "Skipped: $($policy.Description)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Registry path does not exist for: $($policy.Description)" -ForegroundColor Yellow
    }
}

Write-Host "`nAll policies have been processed. Please restart your computer for changes to take effect." -ForegroundColor Cyan