
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

Import-Module -Name Microsoft.WinGet.CommandNotFound

Invoke-Expression (&starship init powershell)