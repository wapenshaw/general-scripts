<#
.SYNOPSIS
    Moves Windows Known Folders to E:\ and updates Windows Known Folder paths.

.DESCRIPTION
    Moves Desktop, Documents, Favorites, Music, Pictures, and Videos to fixed E:\ paths.

    Target layout:
      Desktop   -> E:\OneDrive\Desktop
      Documents -> E:\OneDrive\Documents
      Favorites -> E:\Favorites
      Music     -> E:\Music
      Pictures  -> E:\Pictures
      Videos    -> E:\Videos

    Uses robocopy /MOVE to move existing files, then updates the Windows Known Folder path
    through SHSetKnownFolderPath and the Explorer registry values.

.NOTES
    Run as the logged-in user whose folders are being moved.
    Close Explorer windows and apps using Desktop/Documents/etc. before running.
#>

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath "E:\")) {
    throw "E: drive does not exist."
}

$KnownFolders = @(
    @{
        Name          = "Desktop"
        SpecialFolder = [Environment+SpecialFolder]::DesktopDirectory
        Guid          = "B4BFCC3A-DB2C-424C-B029-7FE99A87C641"
        TargetPath    = "E:\OneDrive\Desktop"
        RegName       = "Desktop"
    },
    @{
        Name          = "Documents"
        SpecialFolder = [Environment+SpecialFolder]::MyDocuments
        Guid          = "FDD39AD0-238F-46AF-ADB4-6C85480369C7"
        TargetPath    = "E:\OneDrive\Documents"
        RegName       = "Personal"
    },
    @{
        Name          = "Favorites"
        SpecialFolder = [Environment+SpecialFolder]::Favorites
        Guid          = "1777F761-68AD-4D8A-87BD-30B759FA33DD"
        TargetPath    = "E:\Favorites"
        RegName       = "Favorites"
    },
    @{
        Name          = "Music"
        SpecialFolder = [Environment+SpecialFolder]::MyMusic
        Guid          = "4BD8D571-6D19-48D3-BE97-422220080E43"
        TargetPath    = "E:\Music"
        RegName       = "My Music"
    },
    @{
        Name          = "Pictures"
        SpecialFolder = [Environment+SpecialFolder]::MyPictures
        Guid          = "33E28130-4E1E-4676-835A-98395C3BC3BB"
        TargetPath    = "E:\Pictures"
        RegName       = "My Pictures"
    },
    @{
        Name          = "Videos"
        SpecialFolder = [Environment+SpecialFolder]::MyVideos
        Guid          = "18989B1D-99B5-455B-841C-AB7C74E4DDFC"
        TargetPath    = "E:\Videos"
        RegName       = "My Video"
    }
)

if (-not ("KnownFolderNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class KnownFolderNative {
    [DllImport("shell32.dll")]
    public static extern int SHSetKnownFolderPath(
        [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
        uint dwFlags,
        IntPtr hToken,
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath
    );
}
"@
}

$UserShellFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
$ShellFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"

function Get-CanonicalPath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue

    if ($resolved) {
        return $resolved.ProviderPath.TrimEnd("\")
    }

    return $Path.TrimEnd("\")
}

function Move-KnownFolderContents {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        Write-Warning "$Name source path is empty. Skipping move."
        return
    }

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        Write-Warning "$Name source does not exist: $SourcePath"
        return
    }

    [System.IO.Directory]::CreateDirectory($TargetPath) | Out-Null

    $sourceCanonical = Get-CanonicalPath -Path $SourcePath
    $targetCanonical = Get-CanonicalPath -Path $TargetPath

    if ($sourceCanonical -ieq $targetCanonical) {
        Write-Host "$Name already points to target. No move required."
        return
    }

    if ($targetCanonical.StartsWith($sourceCanonical + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Name target path is inside source path. Refusing to move recursively."
    }

    Write-Host "Moving $Name contents..."
    Write-Host "  From: $SourcePath"
    Write-Host "  To:   $TargetPath"

    robocopy "$SourcePath" "$TargetPath" /E /MOVE /XJ /COPY:DAT /DCOPY:DAT /R:2 /W:2

    $robocopyExitCode = $LASTEXITCODE

    if ($robocopyExitCode -ge 8) {
        throw "Robocopy failed for $Name with exit code $robocopyExitCode"
    }

    Write-Host "Robocopy completed for $Name with exit code $robocopyExitCode"
}

function Remove-OldFolderIfEmpty {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$OldPath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    if ([string]::IsNullOrWhiteSpace($OldPath)) {
        return
    }

    if (-not (Test-Path -LiteralPath $OldPath)) {
        return
    }

    $oldCanonical = Get-CanonicalPath -Path $OldPath
    $targetCanonical = Get-CanonicalPath -Path $TargetPath

    if ($oldCanonical -ieq $targetCanonical) {
        Write-Host "$Name old path equals target. Not removing."
        return
    }

    $remaining = Get-ChildItem -LiteralPath $OldPath -Force -ErrorAction SilentlyContinue

    if ($remaining) {
        Write-Warning "$Name old folder is not empty, so it was not removed: $OldPath"
        return
    }

    Write-Host "Removing empty old $Name folder: $OldPath"
    Remove-Item -LiteralPath $OldPath -Force -ErrorAction SilentlyContinue
}

foreach ($folder in $KnownFolders) {
    $name = $folder.Name
    $sourcePath = [Environment]::GetFolderPath($folder.SpecialFolder)
    $targetPath = $folder.TargetPath

    Write-Host ""
    Write-Host "==== $name ===="
    Write-Host "Current: $sourcePath"
    Write-Host "Target:  $targetPath"

    Move-KnownFolderContents `
        -Name $name `
        -SourcePath $sourcePath `
        -TargetPath $targetPath

    Write-Host "Setting $name known-folder path..."

    $result = [KnownFolderNative]::SHSetKnownFolderPath(
        [Guid]$folder.Guid,
        0,
        [IntPtr]::Zero,
        $targetPath
    )

    if ($result -ne 0) {
        throw ("Failed to set $name. HRESULT: 0x{0:X8}" -f $result)
    }

    Set-ItemProperty -Path $UserShellFolders -Name $folder.RegName -Value $targetPath
    Set-ItemProperty -Path $ShellFolders     -Name $folder.RegName -Value $targetPath

    Remove-OldFolderIfEmpty `
        -Name $name `
        -OldPath $sourcePath `
        -TargetPath $targetPath

    Write-Host "$name complete."
}

Write-Host ""
Write-Host "Restarting Explorer..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer.exe

Write-Host ""
Write-Host "Known folders now on E:"
Write-Host ""

[Enum]::GetNames([Environment+SpecialFolder]) |
ForEach-Object {
    $specialFolder = [Enum]::Parse([Environment+SpecialFolder], $_)
    $path = [Environment]::GetFolderPath($specialFolder)

    if ($path -like "E:\*") {
        [pscustomobject]@{
            Name = $_
            Path = $path
        }
    }
} |
Sort-Object Name |
Format-Table -AutoSize