<#
.SYNOPSIS
    Imports installed interactive plugins without network or installation work.
.DESCRIPTION
    Defaults come from installed-profile.json. PS_PLUGINS overrides the list;
    PS_PLUGINS=none or PS_DISABLE_PLUGINS=1 disables plugins.
#>
if ($env:PS_DISABLE_PLUGINS -eq '1' -or $env:PS_PLUGINS -eq 'none') { return }
$plugins = if ($null -ne $env:PS_PLUGINS) {
    @($env:PS_PLUGINS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
} else { @($script:ProfilePlugins) }
foreach ($name in $plugins) {
    try {
        Import-Module -Name $name -Global -ErrorAction Stop
        if ($name -eq 'PSFzf') { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r' -ErrorAction Stop }
    } catch {
        Write-Warning "Plugin $name unavailable: $($_.Exception.Message). Re-run Install-Profile.ps1 to deploy dependencies."
    }
}
