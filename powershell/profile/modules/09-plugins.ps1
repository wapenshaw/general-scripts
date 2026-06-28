<#
.SYNOPSIS
  Auto-install and import PSGallery modules on first launch.
.DESCRIPTION
  Module 09 of the modular PowerShell profile. Analogous to zsh's plugins.zsh.
  Override the default list with $env:PS_PLUGINS = 'Terminal-Icons,PSFzf'.
  Set $env:PS_PLUGINS = '' to disable auto-install entirely.
#>

$script:DefaultPSPlugins = @(
    @{ Name = 'Terminal-Icons' }
    @{ Name = 'posh-git' }
    @{ Name = 'PSFzf' }
)

# Resolve plugin list: env var wins
$script:PSPlugins = if ($env:PS_PLUGINS) {
    $env:PS_PLUGINS -split ',' | ForEach-Object { @{ Name = $_.Trim() } } | Where-Object { $_.Name }
} else {
    $script:DefaultPSPlugins
}

# Trust PSGallery on first run so Install-Module doesn't prompt
try {
    if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    }
} catch {
    Write-Verbose "09-plugins: PSGallery trust check skipped: $($_.Exception.Message)"
}

function Import-PSPlugin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Name
    )

    if (-not (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)) {
        Write-Host "[plugin] Installing $Name from PSGallery..." -ForegroundColor DarkYellow
        try {
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop -SkipPublisherCheck
        } catch {
            Write-Warning "[plugin] $Name install failed (will skip): $($_.Exception.Message)"
            return
        }
    }

    try {
        Import-Module -Name $Name -ErrorAction Stop -Global
    } catch {
        Write-Warning "[plugin] $Name import failed (will skip): $($_.Exception.Message)"
    }
}

foreach ($p in $script:PSPlugins) {
    Import-PSPlugin -Name $p.Name
}

# PSFzf key handlers — only if PSFzf actually imported
if (Get-Module -Name PSFzf -ErrorAction SilentlyContinue) {
    try {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction Stop
    } catch {
        Write-Warning "09-plugins: PSFzf options failed: $($_.Exception.Message)"
    }
}
