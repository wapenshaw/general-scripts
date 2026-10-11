<#
.SYNOPSIS
    Installs nvm v2 and standalone pnpm without Corepack or mise.
.DESCRIPTION
    Uses pinned versions from the development manifest. nvm runs in link mode;
    its data uses a dedicated parent directory to isolate nvm's ACL changes.
    Existing correctly versioned pnpm executables are retained.
.EXAMPLE
    ./Install-NodeToolchain.ps1
#>
#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../../config/env/development.json'),
    [string]$Root
)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if (-not $Root) { $Root = $config.root }
function Assert-ToolExit {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed with exit code $LASTEXITCODE." }
}
$nvm = Join-Path $env:LOCALAPPDATA 'Author Software/nvm/nvm.exe'
if (-not (Test-Path -LiteralPath $nvm)) {
    winget install --id CoreyButler.NVMforWindows --exact --version $config.runtimes.nvmVersion --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    Assert-ToolExit 'nvm installation'
}
$nvmRoot = [IO.Path]::GetFullPath((Join-Path $Root $config.runtimes.nvmRoot))
New-Item -ItemType Directory -Path $nvmRoot -Force | Out-Null
$desired = [ordered]@{ root = $nvmRoot; mode = $config.runtimes.nvmMode; cache_downloads = 'true' }
foreach ($key in $desired.Keys) {
    $current = (& $nvm config get $key | Out-String).Trim()
    Assert-ToolExit "Reading nvm $key"
    # nvm 2.0.0 returns exit 1 when an unchanged option is set.
    if ($current -ine $desired[$key]) {
        & $nvm config set "$key=$($desired[$key])"
        Assert-ToolExit "Setting nvm $key"
    }
}
$nodeDir = Join-Path $nvmRoot ('v' + $config.runtimes.nodeVersion)
if (-not (Test-Path -LiteralPath (Join-Path $nodeDir 'node.exe'))) {
    & $nvm install $config.runtimes.nodeVersion --cache
    Assert-ToolExit 'Node installation'
}
& $nvm use $config.runtimes.nodeVersion
Assert-ToolExit 'Node selection'
$missingGlobals = @($config.runtimes.globalNpmPackages | Where-Object {
    $separator = $_.LastIndexOf('@')
    if ($separator -le 0) { throw "Global package must be pinned: $_" }
    $packageName = $_.Substring(0, $separator)
    $packageVersion = $_.Substring($separator + 1)
    $packageJson = Join-Path $nodeDir "node_modules/$packageName/package.json"
    -not (Test-Path -LiteralPath $packageJson) -or
        (Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json).version -ne $packageVersion
})
if ($missingGlobals.Count -gt 0) {
    # Use the selected runtime directly, independent of the caller's inherited PATH.
    $priorPath = $env:Path
    try {
        $env:Path = "$nodeDir;$env:Path"
        & (Join-Path $nodeDir 'node.exe') (Join-Path $nodeDir 'node_modules/npm/bin/npm-cli.js') install --global @missingGlobals
        Assert-ToolExit 'Global npm package deployment'
    } finally { $env:Path = $priorPath }
}
$pnpmHome = [IO.Path]::GetFullPath((Join-Path $Root $config.variables.PNPM_HOME))
$pnpmExe = Join-Path $pnpmHome 'pnpm.exe'
$version = if (Test-Path -LiteralPath $pnpmExe) { & $pnpmExe --version } else { '' }
if ($version -ne $config.runtimes.pnpmVersion) {
    $cliDir = [IO.Path]::GetFullPath((Join-Path $Root $config.runtimes.pnpmCli))
    winget install --id pnpm.pnpm --exact --version $config.runtimes.pnpmVersion --scope user --location $cliDir --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    Assert-ToolExit 'Standalone pnpm installation'
    $binary = Get-ChildItem -LiteralPath $cliDir -Filter pnpm.exe -Recurse -File | Select-Object -First 1
    if (-not $binary) { throw "pnpm.exe was not found under $cliDir." }
    New-Item -ItemType Directory -Path $pnpmHome -Force | Out-Null
    if (Test-Path -LiteralPath $pnpmExe) {
        Copy-Item -LiteralPath $pnpmExe -Destination ($pnpmExe + '.previous') -Force
    }
    Copy-Item -LiteralPath $binary.FullName -Destination $pnpmExe -Force
}
if ((& $pnpmExe --version) -ne $config.runtimes.pnpmVersion) { throw 'pnpm version verification failed.' }
Write-Host 'nvm/Node and standalone pnpm installed. No Corepack activation is needed.'
