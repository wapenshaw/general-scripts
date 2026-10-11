<#
.SYNOPSIS
    Reports command resolution and updater endpoint access in the current shell.
.DESCRIPTION
    Read-only diagnostics compatible with Windows PowerShell 5.1 and PowerShell 7.
    Does not execute an installer or expose proxy credentials. Use -PersistedPath to
    compare a terminal-like PATH rather than the parent application's additions.
.EXAMPLE
    powershell -NoProfile -File ./Test-ShellConnectivity.ps1 -PersistedPath
.EXAMPLE
    pwsh -NoProfile -File ./Test-ShellConnectivity.ps1 -PersistedPath
#>
[CmdletBinding()]
param([switch]$PersistedPath)
if ($PersistedPath) {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
$commands = @()
foreach ($name in @('codex', 'powershell.exe', 'node', 'npm', 'pnpm', 'python', 'uv')) {
    $commands += @(Get-Command $name -All -ErrorAction SilentlyContinue | ForEach-Object {
        @{ name = $name; path = $_.Source; type = $_.CommandType.ToString() }
    })
}
$networkVars = @()
foreach ($name in @('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'NO_PROXY', 'SSL_CERT_FILE', 'NODE_EXTRA_CA_CERTS', 'CODEX_NON_INTERACTIVE', 'CODEX_INSTALL_DAEMON_ONLY', 'CODEX_INSTALL_IF_LATEST', 'CODEX_INSTALL_IF_CURRENT', 'CODEX_INSTALLER_USE_RELEASES_OPENAI_COM')) {
    $value = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ($null -ne $value) {
        if ($name -match 'PROXY' -and $name -ne 'NO_PROXY') { $value = '[set; value redacted]' }
        $networkVars += @{ name = $name; value = $value }
    }
}
$requests = @()
foreach ($uri in @('https://releases.openai.com/codex/channels/latest', 'https://api.github.com/repos/openai/codex/releases/latest', 'https://registry.npmjs.org/@openai%2fcodex/latest')) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 20 -ErrorAction Stop
        $requests += @{ uri = $uri; status = [int]$response.StatusCode; error = $null; ms = $watch.ElapsedMilliseconds }
    } catch {
        $requests += @{ uri = $uri; status = $null; error = $_.Exception.Message; ms = $watch.ElapsedMilliseconds }
    }
}
[ordered]@{
    version = $PSVersionTable.PSVersion.ToString()
    tls = [Net.ServicePointManager]::SecurityProtocol.ToString()
    commands = $commands
    environment = $networkVars
    endpoints = $requests
} | ConvertTo-Json -Depth 5
