<#
.SYNOPSIS
    Opens Windows Explorer in the current directory.

.DESCRIPTION
    Defines the Open-Explorer function (alias: e) which launches explorer.exe at the
    current location.

.EXAMPLE
    PS> e
#>

function Open-Explorer {
    explorer.exe .
}

Set-Alias e Open-Explorer