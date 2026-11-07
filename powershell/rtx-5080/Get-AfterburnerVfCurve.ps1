<#
.SYNOPSIS
    Decodes the V/F curve and settings stored in an MSI Afterburner GPU profile (.cfg).

.DESCRIPTION
    Afterburner saves each GPU's profiles in
    "C:\Program Files (x86)\MSI Afterburner\Profiles\VEN_..&DEV_..&SUBSYS_..&REV_..&BUS_..&DEV_..&FN_...cfg"
    with sections [Startup] (applied at logon when "apply at startup" is on), [Defaults]
    and [ProfileN]. VFCurve= is hex: a 12-byte header (version, point count, reserved)
    then one 12-byte record per point of three little-endian floats:
    voltage (mV), base frequency (MHz), offset (MHz). Effective clock = base + offset.

    Prints PowerLimit / CoreClkBoost / MemClkBoost per section (CoreClkBoost and
    MemClkBoost are stored in kHz) and, for the chosen section, the curve points that
    carry an offset plus the voltage where the curve first reaches its maximum clock.
    That point is the undervolt target (e.g. 2880 MHz at 895 mV).

.PARAMETER Path
    Afterburner GPU profile .cfg. Default: the first NVIDIA (VEN_10DE) profile found.

.PARAMETER Section
    Section whose curve to decode. Default: Startup.

.PARAMETER All
    Print every curve point, not only points with a non-zero offset.

.EXAMPLE
    PS> .\Get-AfterburnerVfCurve.ps1
    PS> .\Get-AfterburnerVfCurve.ps1 -Section Profile1 -All

.NOTES
    Read-only. Record: devices/titan-rtx-5080.md.
#>
[CmdletBinding()]
param(
    [string]$Path,
    [string]$Section = 'Startup',
    [switch]$All
)

if (-not $Path) {
    $dir = Join-Path ${env:ProgramFiles(x86)} 'MSI Afterburner\Profiles'
    $Path = Get-ChildItem -LiteralPath $dir -Filter 'VEN_10DE*.cfg' -ErrorAction Stop |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $Path) { throw "No NVIDIA profile (VEN_10DE*.cfg) in $dir." }
}

$sections = [ordered]@{}
$current = $null
foreach ($line in Get-Content -LiteralPath $Path) {
    if ($line -match '^\[(.+)\]$') { $current = $Matches[1]; $sections[$current] = @{} }
    elseif ($current -and $line -match '^([^=]+)=(.*)$') { $sections[$current][$Matches[1]] = $Matches[2] }
}

"Profile: $Path"
$sections.Keys | Where-Object { $sections[$_].ContainsKey('PowerLimit') } | ForEach-Object {
    $s = $sections[$_]
    [pscustomobject]@{
        Section    = $_
        PowerLimit = "$($s.PowerLimit) %"
        CoreMHz    = [math]::Round([double]$s.CoreClkBoost / 1000, 1)
        MemMHz     = [math]::Round([double]$s.MemClkBoost / 1000, 1)
        FanMode    = $s.FanMode
    }
} | Format-Table -AutoSize | Out-String

$hex = $sections[$Section].VFCurve
if (-not $hex) { throw "Section [$Section] has no VFCurve." }
$bytes = [Convert]::FromHexString($hex)
$count = [BitConverter]::ToUInt32($bytes, 4)

$points = for ($i = 0; $i -lt $count; $i++) {
    $o = 12 + $i * 12
    $mv = [BitConverter]::ToSingle($bytes, $o)
    $base = [BitConverter]::ToSingle($bytes, $o + 4)
    $off = [BitConverter]::ToSingle($bytes, $o + 8)
    [pscustomobject]@{ Index = $i; mV = $mv; BaseMHz = $base; OffsetMHz = $off; EffectiveMHz = $base + $off }
}

$offsetPoints = @($points | Where-Object OffsetMHz -ne 0)
"[$Section] $count points, $($offsetPoints.Count) with an offset"
($All ? $points : $offsetPoints) | Format-Table -AutoSize | Out-String

if ($offsetPoints.Count) {
    $max = ($points | Measure-Object EffectiveMHz -Maximum).Maximum
    $knee = $points | Where-Object EffectiveMHz -ge $max | Select-Object -First 1
    "Curve tops out at $max MHz, first reached at $($knee.mV) mV (index $($knee.Index))."
} else {
    'No offsets: stock curve.'
}
