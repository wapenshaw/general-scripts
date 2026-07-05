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

# Trust PSGallery on first run so Install-Module doesn't prompt.
# Get-PSRepository/Set-PSRepository are slow (network round-trip to the
# gallery API), so only do the trust check once and persist a marker file.
# The InstallationPolicy=Trusted setting itself persists in the registry,
# so re-checking every shell is pure waste (~4s per launch).
$script:PSGalleryTrustMarker = Join-Path $HOME '.config/powershell/.psgallery-trusted'
if (-not (Test-Path -LiteralPath $script:PSGalleryTrustMarker)) {
    try {
        if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        }
        # Marker dir may not exist yet; create it.
        $markerDir = Split-Path -Parent $script:PSGalleryTrustMarker
        if (-not (Test-Path -LiteralPath $markerDir)) {
            New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $script:PSGalleryTrustMarker -Force | Out-Null
    } catch {
        Write-Verbose "09-plugins: PSGallery trust check skipped: $($_.Exception.Message)"
    }
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
}

# Ensure each plugin is installed (cheap: Get-Module -ListAvailable is fast,
# ~10-30ms each). Installs only happen on first launch; subsequent shells
# just verify presence and skip.
foreach ($p in $script:PSPlugins) {
    Import-PSPlugin -Name $p.Name
}

# PSFzf must load eagerly — it registers Ctrl+F / Ctrl+r key handlers that
# need to be in place before the first prompt.
if ($script:PSPlugins.Name -contains 'PSFzf') {
    try {
        Import-Module -Name PSFzf -ErrorAction Stop -Global
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction Stop
    } catch {
        Write-Warning "09-plugins: PSFzf import/options failed: $($_.Exception.Message)"
    }
}

# posh-git is lazy-loaded: it adds a git-status prompt segment that's only
# useful once you run a git command. Importing it eagerly costs ~265ms.
# We defer the import to the first git invocation via a function wrapper
# that self-removes, so subsequent git calls have zero overhead.
#
# Note: if the first git call comes from deep in the call stack (e.g. starship
# invoking git during prompt render), Import-Module may emit a "module nesting
# limit exceeded" warning. The module still loads successfully — the warning
# is cosmetic and only appears once (on the first git call per session).
if ($script:PSPlugins.Name -contains 'posh-git' -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $script:RealGitPath = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
    function global:git {
        Remove-Item -Path Function:git -ErrorAction SilentlyContinue
        try {
            Import-Module -Name posh-git -ErrorAction Stop -Global
        } catch {
            Write-Warning "09-plugins: posh-git import failed: $($_.Exception.Message)"
        }
        & $script:RealGitPath @args
    }
}

# Terminal-Icons is imported eagerly — it decorates Get-ChildItem/Format-Table
# output and there's no single safe entry point to lazy-load on without
# wrapping core cmdlets. At ~300ms it's the cheaper of the two script modules.
if ($script:PSPlugins.Name -contains 'Terminal-Icons') {
    try {
        Import-Module -Name Terminal-Icons -ErrorAction Stop -Global
    } catch {
        Write-Warning "09-plugins: Terminal-Icons import failed: $($_.Exception.Message)"
    }
}
