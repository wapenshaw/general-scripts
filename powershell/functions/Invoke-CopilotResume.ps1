<#
.SYNOPSIS
    Alias `cpr` for `copilot --resume --yolo` - quick resume of the Copilot CLI.

.DESCRIPTION
    Defines the cpr function which runs `copilot --resume --yolo`.

.EXAMPLE
    PS> cpr

.NOTES
    Requires GitHub Copilot CLI.
#>

function cpr { copilot --resume --yolo }
