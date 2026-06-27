<#
User-Profile.ps1

Static profile content copied to $HOME\.config\powershell\user_profile.ps1 by
Install-Profile.ps1. The generated loader in $PROFILE dot-sources this file plus
every *.ps1 in functions\ (via Get-ChildItem).

Add new reusable commands to powershell\functions\<Verb-Noun>.ps1 instead of
editing this file directly.
#>

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

Import-Module -Name Microsoft.WinGet.CommandNotFound

Invoke-Expression (&starship init powershell)

Invoke-Expression (& { (zoxide init powershell | Out-String) })