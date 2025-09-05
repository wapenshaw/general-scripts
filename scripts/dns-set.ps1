#requires -RunAsAdministrator

# --------------------------------------------------------------------------
# --- DEFINE YOUR NETWORK CONFIGURATION ---
# --------------------------------------------------------------------------

# --- General Settings ---
$interfaceAlias = "Ethernet" # <-- IMPORTANT: Replace with your network adapter name (e.g., "Ethernet", "Wi-Fi")

# --- IPv4 Configuration ---
$ipv4Address = "10.10.1.10"
$ipv4Gateway = "10.10.1.1"
$subnetPrefixLength = 23 # This corresponds to a subnet mask of 255.255.254.0

# --- DNS Configuration ---
# Primary IPv4 and IPv6 DNS servers for Cloudflare and Google
$dnsServers = @(
    "1.1.1.1",                     # Cloudflare IPv4
    "8.8.8.8",                     # Google IPv4
    "2606:4700:4700::1111",        # Cloudflare IPv6
    "2001:4860:4860::8888"         # Google IPv6
)

# --- DoH Templates ---
$dohUrlCloudflare = "https://cloudflare-dns.com/dns-query"
$dohUrlGoogle = "https://dns.google/dns-query"

# --------------------------------------------------------------------------
# --- SCRIPT EXECUTION ---
# --------------------------------------------------------------------------

try {
    # --- Get the target network adapter first ---
    $netAdapter = Get-NetAdapter -Name $interfaceAlias
    if (-not $netAdapter) {
        throw "Network adapter '$interfaceAlias' not found."
    }

    Write-Host "--- Starting Network Adapter Reset for '$($netAdapter.Name)' ---"

    # --- Remove Existing IPv4 Addresses ---
    Write-Host "Removing existing IPv4 addresses..."
    Get-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false

    # --- Remove Existing Default Gateway ---
    Write-Host "Removing existing default gateways..."
    Get-NetRoute -InterfaceIndex $netAdapter.InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Remove-NetRoute -Confirm:$false

    # --- Reset DNS Client Server Addresses ---
    Write-Host "Resetting DNS server settings..."
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ResetServerAddresses

    # --- Remove Existing DoH Server Addresses ---
    Write-Host "Removing existing DNS-over-HTTPS (DoH) settings..."
    Get-DnsClientDohServerAddress | Remove-DnsClientDohServerAddress -Confirm:$false
    
    # --- Reset IPv6 to use DHCP ---
    Write-Host "Configuring IPv6 to use DHCP to clear any static settings..."
    Set-NetIPInterface -InterfaceIndex $netAdapter.InterfaceIndex -AddressFamily IPv6 -Dhcp Enabled -ErrorAction Stop

    Write-Host "--- Network Adapter Reset Complete ---" -ForegroundColor Cyan
    Write-Host " "
    
    # --------------------------------------------------------------------------
    # --- APPLYING NEW CONFIGURATION ---
    # --------------------------------------------------------------------------
    
    Write-Host "--- Applying New Network Configuration to '$($netAdapter.Name)' ---"

    # --- Set Static IPv4 Address, Gateway, and Subnet Mask ---
    Write-Host "Configuring IPv4 settings..."
    New-NetIPAddress -InterfaceIndex $netAdapter.InterfaceIndex -IPAddress $ipv4Address -DefaultGateway $ipv4Gateway -PrefixLength $subnetPrefixLength -ErrorAction Stop

    # --- Set All DNS Servers (IPv4 and IPv6) ---
    Write-Host "Setting all IPv4 and IPv6 DNS servers..."
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.InterfaceIndex -ServerAddresses $dnsServers -ErrorAction Stop

    # --- Enable DNS over HTTPS (DoH) for specified servers ---
    Write-Host "Enabling DNS over HTTPS (DoH)..."
    Add-DnsClientDohServerAddress -ServerAddress "1.1.1.1" -DohTemplate $dohUrlCloudflare -AllowFallbackToUdp $false -AutoUpgrade $true
    Add-DnsClientDohServerAddress -ServerAddress "8.8.8.8" -DohTemplate $dohUrlGoogle -AllowFallbackToUdp $false -AutoUpgrade $true
    Add-DnsClientDohServerAddress -ServerAddress "2606:4700:4700::1111" -DohTemplate $dohUrlCloudflare -AllowFallbackToUdp $false -AutoUpgrade $true
    Add-DnsClientDohServerAddress -ServerAddress "2001:4860:4860::8888" -DohTemplate $dohUrlGoogle -AllowFallbackToUdp $false -AutoUpgrade $true

    # --- Enable NetBIOS over TCP/IP ---
    Write-Host "Enabling NetBIOS over TCP/IP..."
    $wmiConfig = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex = $($netAdapter.InterfaceIndex)"
    Invoke-CimMethod -InputObject $wmiConfig -MethodName "SetTcpipNetbios" -Arguments @{TcpipNetbiosOptions = 1 } | Out-Null

    Write-Host "--- Network Configuration Applied Successfully ---" -ForegroundColor Green
}
catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
}