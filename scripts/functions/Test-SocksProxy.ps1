function Test-SocksProxy {
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$Proxy,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$Url
    )

    if (-not $Proxy) {
        $Proxy = Read-Host 'Enter SOCKS proxy (e.g. socks5://127.0.0.1:1080)'
    }
    if (-not $Url) {
        $Url = Read-Host 'Enter target URL (default: https://www.google.com)'
        if (-not $Url) { $Url = 'https://www.google.com' }
    }

    $Username = Read-Host 'Enter proxy username (leave blank if none)'
    $Password = Read-Host 'Enter proxy password (leave blank if none)'

    Write-Host "\n--- SOCKS Proxy Test Details ---" -ForegroundColor Cyan
    Write-Host "Proxy: $Proxy" -ForegroundColor Yellow
    Write-Host "URL: $Url" -ForegroundColor Yellow
    if ($Username) { Write-Host "Username: $Username" -ForegroundColor Yellow }
    else { Write-Host "Username: (none)" -ForegroundColor Yellow }
    Write-Host "-------------------------------\n" -ForegroundColor Cyan

    # Detect and prepend socks5:// if missing
    if ($Proxy -and ($Proxy -notmatch '^(socks5h?|socks4a?)://')) {
        $Proxy = "socks5://$Proxy"
        Write-Host "Info: Proxy protocol not specified, assuming socks5://" -ForegroundColor DarkYellow
    }

    Write-Host "Testing SOCKS proxy: $Proxy -> $Url" -ForegroundColor Cyan

    $proxyAuth = ''
    if ($Username -and $Password) {
        $proxyAuth = "--proxy-user `"$Username`:$Password`""
    }

    try {
        $cmd = "curl --verbose --proxy $Proxy $proxyAuth --max-time 10 $Url 2>&1"
        Write-Host "Running command: $cmd" -ForegroundColor DarkGray
        $result = Invoke-Expression $cmd
        if ($LASTEXITCODE -eq 0 -and $result) {
            Write-Host "Connection successful!" -ForegroundColor Green
        }
        else {
            Write-Host "Connection failed. Output:" -ForegroundColor Red
            Write-Host $result
            if ($result -match 'curl: \(56\) Proxy CONNECT aborted') {
                Write-Host "Explanation: The error 'curl: (56) Proxy CONNECT aborted' usually means the proxy server refused or could not establish a connection to the target site. This can be due to: " -ForegroundColor Yellow
                Write-Host "- Incorrect proxy address or port" -ForegroundColor Yellow
                Write-Host "- Proxy authentication failure (wrong username/password)" -ForegroundColor Yellow
                Write-Host "- Proxy does not allow CONNECT to the requested site/port" -ForegroundColor Yellow
                Write-Host "- Network/firewall issues between you and the proxy or the proxy and the target site" -ForegroundColor Yellow
            }
            elseif ($result -match 'Could not resolve proxy') {
                Write-Host "Explanation: The proxy hostname could not be resolved. Check the proxy address for typos or DNS issues." -ForegroundColor Yellow
            }
            elseif ($result -match 'curl: \(7\)') {
                Write-Host "Explanation: curl error 7 usually means failed to connect to the proxy. This can be due to the proxy being offline, wrong port, or blocked by a firewall." -ForegroundColor Yellow
            }
            elseif ($result -match 'curl: \(52\)') {
                Write-Host "Explanation: curl error 52 means an empty reply from the server. The proxy may be up but not responding as expected." -ForegroundColor Yellow
            }
            elseif ($result -match 'curl: \(35\)') {
                Write-Host "Explanation: curl error 35 is an SSL connect error. This may be due to SSL/TLS issues between curl and the proxy or the target site." -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
}

Set-Alias -Name testsocks -Value Test-SocksProxy -Scope Global
# Usage: testsocks
