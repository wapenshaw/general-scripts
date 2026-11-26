<#
.SYNOPSIS
  Alias definitions.
.DESCRIPTION
  Module 06 of the modular PowerShell profile. Depends on 02-exports.
  Add new aliases here — keeps them in one place like zsh's aliases.zsh.
#>

# Probe PATH directly instead of Get-Command: for a tool that is not installed,
# Get-Command walks every PATH entry and PATHEXT extension (~90 ms per miss).
$exeProbe = {
    param([string]$Name)
    $suffixes = if ($IsWindows) { '.exe', '.cmd', '.bat' } else { '' }
    foreach ($dir in $env:PATH.Split([IO.Path]::PathSeparator)) {
        if (-not $dir) { continue }
        foreach ($suffix in $suffixes) {
            if ([IO.File]::Exists([IO.Path]::Combine($dir, $Name + $suffix))) { return $true }
        }
    }
    $false
}

# eza / ls replacement
if (& $exeProbe 'eza') {
    Set-Alias -Name ls -Value eza -Option AllScope -Force
}

# bat / cat replacement
if (& $exeProbe 'bat') {
    Set-Alias -Name cat -Value bat -Option AllScope -Force
}

# rg / grep replacement
if (& $exeProbe 'rg') {
    Set-Alias -Name grep -Value rg -Option AllScope -Force
}

Remove-Variable exeProbe
