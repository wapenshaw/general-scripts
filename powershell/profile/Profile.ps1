<#
.SYNOPSIS
    Loads the installed profile manifest without installing dependencies.
.DESCRIPTION
    Scripts skip shell UI unless PS_PROFILE_IN_SCRIPTS=1. Configuration is local.
#>
#requires -Version 7.0
$script:ProfileStart = [Diagnostics.Stopwatch]::StartNew()
$script:ProfileLoadErrors = @()
$script:ProfileLaunchArgs = [Environment]::GetCommandLineArgs()
# VS Code shell integration uses -NoExit -Command; its extension uses a custom host.
$script:ProfileInteractiveHost = $Host.Name -eq 'Visual Studio Code Host' -or
    (($script:ProfileLaunchArgs -contains '-NoExit') -and
     -not ($script:ProfileLaunchArgs -contains '-NonInteractive'))
if ($env:PS_PROFILE_IN_SCRIPTS -ne '1' -and -not $script:ProfileInteractiveHost -and
    ($script:ProfileLaunchArgs | Where-Object { $_ -match '^-(NonInteractive|Command|CommandWithArgs|EncodedCommand|File|c|f)$' })) { return }
$script:ProfileConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'installed-profile.json') -Raw | ConvertFrom-Json
$script:ProfilePlugins = @($script:ProfileConfig.plugins)
if ($script:ProfilePlugins.Count -gt 0) {
    # Prefer local dependencies while retaining externally managed module stores.
    $env:PSModulePath = (@($script:ProfileConfig.moduleDir) + @($env:PSModulePath -split ';')) |
        Where-Object { $_ } | Select-Object -Unique | Join-String -Separator ';'
}
if ($script:ProfileConfig.work) {
    $env:PS_WORK = '1'
    $env:PS_ASSURANT = '1'
}
foreach ($relativePath in @($script:ProfileConfig.coreModules) + @($script:ProfileConfig.workModules)) {
    try { . (Join-Path $PSScriptRoot $relativePath) }
    catch {
        $script:ProfileLoadErrors += $relativePath
        Write-Warning "$relativePath`: $($_.Exception.Message)"
    }
}
try {
    . (Join-Path $PSScriptRoot 'Register-ProfileFunctions.ps1')
    Register-ProfileFunctions -FunctionsDir (Join-Path $PSScriptRoot 'functions')
} catch {
    $script:ProfileLoadErrors += 'Register-ProfileFunctions'
    Write-Warning "Profile functions: $($_.Exception.Message)"
}
# Prompt initialization follows work settings and helper registration.
foreach ($relativePath in @($script:ProfileConfig.promptModules)) {
    try { . (Join-Path $PSScriptRoot $relativePath) }
    catch {
        $script:ProfileLoadErrors += $relativePath
        Write-Warning "$relativePath`: $($_.Exception.Message)"
    }
}
$script:ProfileStart.Stop()
if ($env:PS_PROFILE_DEBUG -eq '1') {
    Write-Host "[profile] $($script:ProfileStart.ElapsedMilliseconds) ms; errors=$($script:ProfileLoadErrors.Count)" -ForegroundColor DarkGray
}
