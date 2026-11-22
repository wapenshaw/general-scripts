<#
.SYNOPSIS
  Optionally start Herdr terminals in one fixed folder.
.DESCRIPTION
  Module 07 of the modular PowerShell profile. Off by default: it does nothing
  unless the HERDR_START_DIR environment variable is set (for example as a user
  variable). Herdr core sets HC_TERMINAL_ID in every terminal it spawns, so
  ordinary shells are untouched. HERDR_CD_DONE stops nested shells from jumping
  again.
#>

if ($env:HERDR_START_DIR -and $env:HC_TERMINAL_ID -and -not $env:HERDR_CD_DONE) {
    $env:HERDR_CD_DONE = '1'
    if (Test-Path -LiteralPath $env:HERDR_START_DIR -PathType Container) { Set-Location -LiteralPath $env:HERDR_START_DIR }
}
