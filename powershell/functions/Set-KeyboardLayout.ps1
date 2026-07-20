<#
.SYNOPSIS
    Sets the Windows keyboard input language list to en-IN.

.DESCRIPTION
    Defines the Set-KeyboardLayout function (alias: skl) which prints the current
    layout and replaces the user language list with en-IN.

.EXAMPLE
    PS> skl

.NOTES
    No admin required. The current list is replaced, not appended to.
#>

function Set-KeyboardLayout {
    [CmdletBinding()]
    param ()

    $CurrentLayout = (Get-WinUserLanguageList)[0]
    Write-Host "Current keyboard layout: $($CurrentLayout.LanguageTag)"

    $Tags = @("en-IN")
    $Layouts = $Tags | ForEach-Object {
        (New-WinUserLanguageList $_)[0]
    }
    Set-WinUserLanguageList -LanguageList $Layouts -Confirm:$false -Force -Verbose
    Get-WinUserLanguageList | Format-List 'LanguageTag', 'EnglishName'
}

Set-Alias -Name skl -Value Set-KeyboardLayout -Scope Global -Force