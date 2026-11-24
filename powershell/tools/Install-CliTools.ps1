#requires -Version 7.0
<#
.SYNOPSIS
    Install or update the Wiz, Snyk and Postman command-line tools on Windows.

.DESCRIPTION
    Standalone installer for three vendor CLIs. It is independent of the workstation,
    profile and winget scripts in this repo and needs no administrator rights, winget,
    npm or Node.js.

    Tool        Source                                   Installed to
    ----------  ---------------------------------------  --------------------------------
    Wiz CLI     downloads.wiz.io (v1, latest)            ~\.local\bin\wizcli.exe
    Snyk CLI    downloads.snyk.io (stable)               ~\.local\bin\snyk.exe
    Postman CLI dl-cli.pstmn.io (latest, win64 zip)      %LOCALAPPDATA%\Microsoft\WindowsApps

    Postman CLI is installed to the same place as the official installer and `postman update`
    so both keep working. It is a multi-file install (postman.exe plus a lib folder), which
    is why it does not go in ~\.local\bin.

    The latest version is read from the vendor before anything is downloaded, so a run with
    nothing new transfers a few kilobytes instead of ~500 MB:
    - Wiz:     the SHA-256 the vendor publishes in the download's response headers.
    - Snyk:    the vendor's published .sha256 file.
    - Postman: the version in the download's file name, compared with `postman --version`.

    Downloads are verified before they replace anything: a Windows executable header and the
    vendor SHA-256 for Wiz and Snyk, and a valid Authenticode signature from "Postman, Inc."
    for Postman. A running executable is moved aside instead of overwritten, so updating a
    tool that is open does not fail. If the swap fails, the previous version is restored.

    ~\.local\bin is added to the user PATH only when Wiz or Snyk is selected.

.PARAMETER Wiz
    Select Wiz CLI. With no tool switch, all three tools are selected.

.PARAMETER Snyk
    Select Snyk CLI.

.PARAMETER Postman
    Select Postman CLI.

.PARAMETER Check
    Report installed versus latest for the selected tools without installing anything.

.PARAMETER Force
    Download and reinstall even when the installed copy is already current.

.PARAMETER List
    Print the selected tools and their download URLs, then exit.

.EXAMPLE
    PS> .\Install-CliTools.ps1

    Install or update Wiz, Snyk and Postman.

.EXAMPLE
    PS> .\Install-CliTools.ps1 -Postman -Snyk

    Install or update only Postman CLI and Snyk CLI.

.EXAMPLE
    PS> .\Install-CliTools.ps1 -Check

    Show which tools are current without installing.

.NOTES
    Requires PowerShell 7+ and Windows x64. Uses vendor-hosted HTTPS downloads.
    Does not touch copies installed by winget, npm or Scoop elsewhere on PATH.
    Exit code is 1 if any selected tool fails.
#>
[CmdletBinding()]
param(
    [switch]$Wiz,
    [switch]$Snyk,
    [switch]$Postman,
    [switch]$Check,
    [switch]$Force,
    [switch]$List
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not $IsWindows -or
    [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -ne
    [Runtime.InteropServices.Architecture]::X64) {
    throw 'This script requires Windows x64 and PowerShell 7+.'
}

$BinDir = Join-Path $HOME '.local\bin'
$PostmanDir = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
$PostmanUrl = 'https://dl-cli.pstmn.io/download/latest/win64'

$Tools = @(
    @{ Key = 'Wiz'; Name = 'Wiz CLI'; Kind = 'Exe'; Command = 'wizcli'; VersionArg = 'version'
       Url = 'https://downloads.wiz.io/v1/wizcli/latest/wizcli-windows-amd64.exe' }
    @{ Key = 'Snyk'; Name = 'Snyk CLI'; Kind = 'Exe'; Command = 'snyk'; VersionArg = '--version'
       Url = 'https://downloads.snyk.io/cli/stable/snyk-win.exe'
       HashUrl = 'https://downloads.snyk.io/cli/stable/snyk-win.exe.sha256' }
    @{ Key = 'Postman'; Name = 'Postman CLI'; Kind = 'Postman'; Command = 'postman'; Url = $PostmanUrl }
)

if (-not ($Wiz -or $Snyk -or $Postman)) { $Wiz = $Snyk = $Postman = $true }
$Selected = @($Tools | Where-Object {
    ($_.Key -eq 'Wiz' -and $Wiz) -or ($_.Key -eq 'Snyk' -and $Snyk) -or ($_.Key -eq 'Postman' -and $Postman)
})

if ($List) {
    $Selected | ForEach-Object { Write-Host ('{0,-12} {1}' -f $_.Name, $_.Url) }
    return
}

#region helpers

function Get-HeaderValue {
    param($Response, [string]$Name)
    $value = $Response.Headers[$Name]
    if ($value) { [string]($value | Select-Object -First 1) }
}

function Get-ResponseText {
    param($Response)
    $text = if ($Response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($Response.Content) }
            else { [string]$Response.Content }
    $text.Trim()
}

function Get-ToolVersion {
    param([string]$Exe, [string[]]$Arguments)
    if (-not (Test-Path -LiteralPath $Exe)) { return $null }
    try {
        # Capture stdout and stderr (Wiz prints its version to stderr). Reading everything, rather than
        # stopping the pipe early with Select -First 1, keeps $LASTEXITCODE reliable.
        $lines = @(& $Exe @Arguments 2>&1)
        if ($LASTEXITCODE -eq 0 -and $lines) {
            # Some CLIs (Wiz) print a banner first, so prefer the first line holding a version number.
            $versionLine = $lines | Where-Object { "$_" -match '\d+\.\d+\.\d+' } | Select-Object -First 1
            return ([string]($versionLine ?? $lines[0])).Trim()
        }
    }
    catch { }
    return $null
}

function Test-PeFile {
    # True when the file is large enough and starts with the "MZ" executable header.
    param([string]$Path, [long]$MinimumBytes = 1MB)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $stream.Length -ge $MinimumBytes -and $stream.ReadByte() -eq 0x4D -and $stream.ReadByte() -eq 0x5A
    }
    finally { $stream.Dispose() }
}

function Add-UserPath {
    param([string]$Directory)
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($Directory -notin @($userPath -split ';')) {
        [Environment]::SetEnvironmentVariable('Path', (@($userPath, $Directory) | Where-Object { $_ }) -join ';', 'User')
    }
    $env:Path = (@($Directory) + @($env:Path -split ';' | Where-Object {
        $_ -and $_.TrimEnd('\') -ine $Directory.TrimEnd('\')
    })) -join ';'
}

function New-Result {
    param($Tool, [string]$Status, [string]$Version, [string]$Latest)
    [pscustomobject]@{ Tool = $Tool.Name; Status = $Status; Installed = $Version; Latest = $Latest }
}

function Write-RecoveryWarning {
    # Surfaces files kept after a failed update; they may be the only copy of the previous install.
    param([string]$Directory, [string[]]$Filters)
    foreach ($filter in $Filters) {
        Get-ChildItem -LiteralPath $Directory -Filter $filter -Force -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Warning "Previous install kept at: $($_.FullName)" }
    }
}

#endregion

#region single-file tools (Wiz, Snyk)

function Get-ExpectedHash {
    # SHA-256 published by the vendor, or $null when it cannot be read or is not 64 hex characters.
    param($Tool)
    try {
        $hash = if ($Tool.HashUrl) {
            ((Get-ResponseText (Invoke-WebRequest -Uri $Tool.HashUrl)) -split '\s+')[0]
        }
        else {
            Get-HeaderValue (Invoke-WebRequest -Uri $Tool.Url -Method Head) 'x-amz-meta-sha256'
        }
        if ($hash -match '^[0-9a-fA-F]{64}$') { return $hash }
    }
    catch { }
    return $null
}

function Install-SingleExe {
    param($Tool)

    $target = Join-Path $BinDir "$($Tool.Command).exe"
    $present = Test-Path -LiteralPath $target
    # Kept copies from a failed update; .old files only matter when no exe exists (otherwise they are disposable leftovers).
    Write-RecoveryWarning $BinDir (@("$($Tool.Command).exe.recovery-*") + $(if (-not $present) { "$($Tool.Command).*.old" }))
    $version = Get-ToolVersion $target @($Tool.VersionArg)
    $expected = Get-ExpectedHash $Tool
    $localHash = if ($present) { (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash }

    if ($present -and $expected -and $localHash -ieq $expected) {
        if (-not $Force -or $Check) { return New-Result $Tool 'Current' $version $expected.Substring(0, 12) }
    }
    if ($Check) {
        $status = if (-not $present) { 'Not installed' } elseif ($expected) { 'Update available' } else { 'Unknown (no vendor hash)' }
        return New-Result $Tool $status $version ($expected ? $expected.Substring(0, 12) : $null)
    }

    # Never install an unverified binary, not even with -Force.
    if (-not $expected) {
        throw 'Could not read a valid vendor SHA-256 (64 hex characters); refusing to install an unverified binary.'
    }
    $temp = Join-Path $BinDir "$($Tool.Command).$([guid]::NewGuid().ToString('N')).tmp"
    try {
        Write-Host "    Downloading $($Tool.Url)"
        Invoke-WebRequest -Uri $Tool.Url -OutFile $temp
        if (-not (Test-PeFile $temp)) { throw 'Downloaded file is not a valid Windows executable.' }

        $newHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash
        if ($expected -and $newHash -ine $expected) {
            throw "SHA-256 mismatch (expected $expected, got $newHash)."
        }
        if ($present -and $newHash -ieq $localHash -and -not $Force) {
            return New-Result $Tool 'Current' $version $newHash.Substring(0, 12)
        }

        # Windows will not overwrite a running exe but lets it be renamed, so move it aside.
        # Leftover .old copies are disposable only while the current exe exists; with no exe
        # they could be the only copy, so they are kept.
        if ($present) {
            Get-ChildItem -LiteralPath $BinDir -Filter "$($Tool.Command).*.old" -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
        $aside = "$target.$([guid]::NewGuid().ToString('N')).old"
        if ($present) { Move-Item -LiteralPath $target -Destination $aside -Force }
        try { Move-Item -LiteralPath $temp -Destination $target -Force }
        catch {
            $failure = $_
            if ($present) {
                try { Move-Item -LiteralPath $aside -Destination $target -Force -ErrorAction Stop }
                catch {
                    $restoreError = $_.Exception.Message
                    $saved = "$target.recovery-$([guid]::NewGuid().ToString('N'))"
                    try { Move-Item -LiteralPath $aside -Destination $saved -ErrorAction Stop } catch { $saved = $aside }
                    throw "Install failed ($($failure.Exception.Message)) and the previous $($Tool.Name) could not be restored ($restoreError). Previous copy saved at: $saved"
                }
            }
            throw $failure
        }
        if ($present) { Remove-Item -LiteralPath $aside -Force -ErrorAction SilentlyContinue }

        $status = if (-not $present) { 'Installed' } elseif ($newHash -ieq $localHash) { 'Reinstalled' } else { 'Updated' }
        return New-Result $Tool $status (Get-ToolVersion $target @($Tool.VersionArg)) $newHash.Substring(0, 12)
    }
    finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

#endregion

#region Postman CLI

function Install-PostmanFiles {
    # Moves each staged item into place, retiring any existing one first (a running
    # postman.exe can be renamed but not deleted). Restores the old files on failure.
    param([string]$Staging, [string]$Destination)

    # Only folders from earlier successful updates (old files that were still running) are disposable.
    Get-ChildItem -LiteralPath $Destination -Directory -Filter '.postman-cli-retired-*' -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

    $retired = Join-Path $Destination ".postman-cli-retired-$([guid]::NewGuid())"
    $retiredNames = @()
    $installedNames = @()
    try {
        foreach ($item in @(Get-ChildItem -LiteralPath $Staging -Force)) {
            $dest = Join-Path $Destination $item.Name
            if (Test-Path -LiteralPath $dest) {
                if (-not (Test-Path -LiteralPath $retired)) { New-Item -ItemType Directory -Path $retired | Out-Null }
                Move-Item -LiteralPath $dest -Destination (Join-Path $retired $item.Name)
                $retiredNames += $item.Name
            }
            Move-Item -LiteralPath $item.FullName -Destination $dest
            $installedNames += $item.Name
        }
    }
    catch {
        $failure = $_
        $restoreErrors = @()
        foreach ($name in $installedNames) {
            try { Remove-Item -LiteralPath (Join-Path $Destination $name) -Recurse -Force -ErrorAction Stop }
            catch { $restoreErrors += "remove new ${name}: $($_.Exception.Message)" }
        }
        foreach ($name in $retiredNames) {
            try { Move-Item -LiteralPath (Join-Path $retired $name) -Destination (Join-Path $Destination $name) -ErrorAction Stop }
            catch { $restoreErrors += "restore ${name}: $($_.Exception.Message)" }
        }
        if (-not $restoreErrors) {
            Remove-Item -LiteralPath $retired -Recurse -Force -ErrorAction SilentlyContinue
            throw "Postman CLI install failed and was rolled back: $($failure.Exception.Message)"
        }
        # The retired folder may hold the only intact copy, so rename it out of the cleanup filter and keep it.
        $saved = Join-Path $Destination ".postman-cli-recovery-$([guid]::NewGuid())"
        try { Move-Item -LiteralPath $retired -Destination $saved -ErrorAction Stop } catch { $saved = $retired }
        throw ("Postman CLI install failed ($($failure.Exception.Message)) and the rollback was incomplete: " +
            ($restoreErrors -join '; ') + ". Previous files saved at: $saved")
    }
    Remove-Item -LiteralPath $retired -Recurse -Force -ErrorAction SilentlyContinue
}

function Install-PostmanCli {
    param($Tool)

    $exe = Join-Path $PostmanDir 'postman.exe'
    $current = Get-ToolVersion $exe @('--version')
    Write-RecoveryWarning $PostmanDir @('.postman-cli-recovery-*')

    $disposition = Get-HeaderValue (Invoke-WebRequest -Uri $PostmanUrl -Method Head) 'Content-Disposition'
    $latest = if ($disposition -match 'postman-cli-(\d+(?:\.\d+)+)-windows') { $Matches[1] }

    if ($current -and $latest -and $current -eq $latest -and -not $Force) {
        return New-Result $Tool 'Current' $current $latest
    }
    if ($Check) {
        $status = if (-not (Test-Path -LiteralPath $exe)) { 'Not installed' }
                  elseif (-not $latest) { 'Unknown (latest version not readable)' }
                  else { 'Update available' }
        return New-Result $Tool $status $current $latest
    }

    # Short staging path: the zip contains a deep node_modules tree and extraction fails past 260 chars.
    $staging = Join-Path $env:TEMP ('pcli-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $staging -Force | Out-Null
    New-Item -ItemType Directory -Path $PostmanDir -Force | Out-Null
    try {
        $zip = Join-Path $staging 'postman-cli.zip'
        Write-Host "    Downloading $PostmanUrl"
        Invoke-WebRequest -Uri $PostmanUrl -OutFile $zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $staging)
        Remove-Item -LiteralPath $zip -Force

        $staged = Join-Path $staging 'postman-cli.exe'
        $signature = Get-AuthenticodeSignature -FilePath $staged
        $signer = if ($signature.SignerCertificate) {
            $signature.SignerCertificate.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false)
        }
        if ($signature.Status -ne 'Valid' -or $signer -ne 'Postman, Inc.') {
            throw "Signature check failed (status: $($signature.Status), signer: $signer)."
        }

        Rename-Item -LiteralPath $staged -NewName 'postman.exe'
        Install-PostmanFiles -Staging $staging -Destination $PostmanDir
    }
    finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }

    $status = if (-not $current) { 'Installed' } elseif ($current -eq $latest) { 'Reinstalled' } else { 'Updated' }
    return New-Result $Tool $status (Get-ToolVersion $exe @('--version')) $latest
}

#endregion

if (-not $Check -and ($Wiz -or $Snyk)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
    Add-UserPath $BinDir
}

$Results = @()
foreach ($tool in $Selected) {
    Write-Host ''
    Write-Host "[*] $($tool.Name) ..." -ForegroundColor Cyan
    try {
        $result = if ($tool.Kind -eq 'Postman') { Install-PostmanCli $tool } else { Install-SingleExe $tool }
    }
    catch {
        Write-Warning "$($tool.Name): $($_.Exception.Message)"
        $result = New-Result $tool 'Failed' $null $null
    }
    $color = switch -Wildcard ($result.Status) {
        'Failed' { 'Red' } 'Current' { 'Green' } 'Updated' { 'Green' } 'Installed' { 'Green' } default { 'Yellow' }
    }
    Write-Host "    $($result.Status)$(if ($result.Installed) { " ($($result.Installed))" })" -ForegroundColor $color
    $Results += $result
}

Write-Host ''
$Results | Format-Table Tool, Status, Installed, Latest -AutoSize | Out-String | Write-Host

if ($Results | Where-Object Status -eq 'Failed') { exit 1 }
