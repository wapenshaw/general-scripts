<#
.SYNOPSIS
    Toggles the NVIDIA DLSS overlay indicator on or off.

.DESCRIPTION
    Flips HKLM:\SOFTWARE\NVIDIA Corporation\Global\NGXCore\ShowDlssIndicator between
    1024 (visible) and 0 (hidden). The new state is printed.

.EXAMPLE
    PS> pwsh -File .\Set-DlssIndicator.ps1

.NOTES
    Run from an elevated PowerShell session. The NGXCore key is only present if
    NVIDIA App / NGX is installed.
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrator privileges. Please run as Administrator." -ForegroundColor Red
    exit 1
}

$path = "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NGXCore";
$name = "ShowDlssIndicator";

if (Test-Path $path) {
    $v = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name;

    Set-ItemProperty -Path $path -Name $name -Value $(if ($v -eq 1024) { 0 }else { 1024 });
    Write-Host $("DLSS Indicator " + $(if ($v -eq 1024) { "Disabled." }else { "Enabled." })) 
}
else { Write-Host "Registry path not found." }