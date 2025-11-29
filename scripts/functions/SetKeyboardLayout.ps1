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

Set-Alias -Name skl -Value Set-KeyboardLayout -Force