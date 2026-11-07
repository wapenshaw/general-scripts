<#
.SYNOPSIS
    Writes an undervolt V/F curve into an MSI Afterburner profile slot, and optionally applies it.

.DESCRIPTION
    Builds the same curve shape as a hand-made Afterburner undervolt:
      - points below -FromMv keep the stock clock (offset 0)
      - points from -FromMv up to -TargetMv get +Offset MHz
      - every point above -TargetMv is flattened to the clock reached at -TargetMv
    The GPU therefore never runs above -TargetMv under load, and idle (low P-states)
    is untouched.

    Stock base clocks come from the profile's [Defaults] section (captured by Afterburner
    from the driver), so offsets are relative to the real stock curve. PowerLimit,
    MemClkBoost, CoreClkBoost and fan settings are copied from -TemplateSection
    (default Startup) unless -PowerLimit / -MemOffset are given.

    VFCurve format: 12-byte header (version, point count, reserved) then one 12-byte
    record per point of three little-endian float32s: mV, base MHz, offset MHz.

    -Apply runs "MSIAfterburner.exe -Profile<Slot>" so the running Afterburner loads it.
    Afterburner rewrites its .cfg on save/exit, so write slots while you are not editing
    profiles in its UI.

.PARAMETER TargetMv
    Highest voltage the GPU may use (the flat part starts here), e.g. 925.

.PARAMETER Offset
    MHz added to the stock curve from -FromMv to -TargetMv. +468 is the original
    Afterburner undervolt; mVolt+ testing found +525 best and +550/+575 unstable at 900 mV.

.PARAMETER Slot
    Afterburner profile slot (1-5) to write. Default 2.

.PARAMETER FromMv
    Lowest voltage that gets the offset. Default 810 (as in the original curve).

.PARAMETER MemOffset
    Memory offset in MHz. Default: copied from the template section.

.PARAMETER PowerLimit
    Power limit percent. Default: copied from the template section.

.PARAMETER TemplateSection
    Section to copy the other settings from. Default Startup.

.PARAMETER Apply
    Load the slot in the running Afterburner after writing it.

.PARAMETER Path
    Afterburner GPU .cfg. Default: the first VEN_10DE profile.

.PARAMETER AfterburnerPath
    MSIAfterburner.exe. Default: C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe.

.EXAMPLE
    PS> .\Set-AfterburnerVfCurve.ps1 -TargetMv 925 -Offset 480 -Slot 2 -Apply
    Writes "+480 up to 925 mV, flat at 3015 MHz" to profile 2 and loads it.

.NOTES
    Writes under Program Files: run elevated. Backs up the .cfg once per run next to
    itself (*.cfg.bak-<stamp>). Decode with Get-AfterburnerVfCurve.ps1.
    Record: devices/titan-rtx-5080.md.
#>
#requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidateRange(800, 1100)][int]$TargetMv,
    [Parameter(Mandatory)][ValidateRange(-500, 700)][int]$Offset,
    [ValidateRange(1, 5)][int]$Slot = 2,
    [int]$FromMv = 810,
    [ValidateRange(-1000, 3000)][int]$MemOffset,
    [ValidateRange(69, 111)][int]$PowerLimit,
    [string]$TemplateSection = 'Startup',
    [switch]$Apply,
    [string]$Path,
    [string]$AfterburnerPath = 'C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe'
)

if (-not $Path) {
    $dir = Join-Path ${env:ProgramFiles(x86)} 'MSI Afterburner\Profiles'
    $Path = Get-ChildItem -LiteralPath $dir -Filter 'VEN_10DE*.cfg' -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $Path) { throw "No NVIDIA profile (VEN_10DE*.cfg) in $dir." }
}

# Parse the ini, keeping section order and key order.
$sections = [ordered]@{}
$current = $null
foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\[(.+)\]$') { $current = $Matches[1]; $sections[$current] = [ordered]@{} }
    elseif ($current -and $line -match '^([^=]+)=(.*)$') { $sections[$current][$Matches[1]] = $Matches[2] }
}
foreach ($need in 'Defaults', $TemplateSection) {
    if (-not $sections.Contains($need) -or -not $sections[$need].VFCurve) { throw "[$need] with a VFCurve is missing from $Path." }
}

# Stock bases from [Defaults].
$bytes = [Convert]::FromHexString($sections['Defaults'].VFCurve)
$count = [BitConverter]::ToUInt32($bytes, 4)
$mv = [float[]]::new($count); $base = [float[]]::new($count)
for ($i = 0; $i -lt $count; $i++) {
    $o = 12 + $i * 12
    $mv[$i] = [BitConverter]::ToSingle($bytes, $o)
    $base[$i] = [BitConverter]::ToSingle($bytes, $o + 4)
}
$top = -1
for ($i = 0; $i -lt $count; $i++) { if ($mv[$i] -le $TargetMv) { $top = $i } }
if ($top -lt 0 -or $mv[$top] -lt $FromMv) { throw "TargetMv $TargetMv is below FromMv $FromMv or the curve." }
$flat = $base[$top] + $Offset

# New curve: same header, new offsets.
$out = [byte[]]::new($bytes.Length)
[Array]::Copy($bytes, $out, 12)
for ($i = 0; $i -lt $count; $i++) {
    $off = if ($mv[$i] -lt $FromMv) { 0 } elseif ($i -le $top) { $Offset } else { $flat - $base[$i] }
    $o = 12 + $i * 12
    [BitConverter]::GetBytes([float]$mv[$i]).CopyTo($out, $o)
    [BitConverter]::GetBytes([float]$base[$i]).CopyTo($out, $o + 4)
    [BitConverter]::GetBytes([float]$off).CopyTo($out, $o + 8)
}
if ($bytes.Length -gt 12 + $count * 12) { [Array]::Copy($bytes, 12 + $count * 12, $out, 12 + $count * 12, $bytes.Length - 12 - $count * 12) }

$section = [ordered]@{}
foreach ($k in $sections[$TemplateSection].Keys) { $section[$k] = $sections[$TemplateSection][$k] }
$section['VFCurve'] = [Convert]::ToHexString($out)
if ($PSBoundParameters.ContainsKey('MemOffset')) { $section['MemClkBoost'] = "$($MemOffset * 1000)" }
if ($PSBoundParameters.ContainsKey('PowerLimit')) { $section['PowerLimit'] = "$PowerLimit" }
$sections["Profile$Slot"] = $section

$what = "Profile$Slot = +$Offset MHz from $FromMv to $($mv[$top]) mV, flat at $flat MHz (power $($section.PowerLimit) %, memory $([double]$section.MemClkBoost / 1000) MHz)"
if (-not $PSCmdlet.ShouldProcess($Path, $what)) { return }

Copy-Item -LiteralPath $Path -Destination "$Path.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
$lines = foreach ($name in $sections.Keys) {
    "[$name]"
    foreach ($k in $sections[$name].Keys) { "$k=$($sections[$name][$k])" }
}
Set-Content -LiteralPath $Path -Value $lines -Encoding ascii
"Wrote $what."

if ($Apply) {
    if (-not (Get-Process MSIAfterburner -ErrorAction SilentlyContinue)) { throw 'Afterburner is not running; start it, then apply the profile.' }
    Start-Process -FilePath $AfterburnerPath -ArgumentList "-Profile$Slot"
    "Applied Profile$Slot."
}
