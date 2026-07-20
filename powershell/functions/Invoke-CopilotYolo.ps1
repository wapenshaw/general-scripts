<#
.SYNOPSIS
    Wraps `copilot --yolo --resume` for quick re-entry into the GitHub Copilot CLI.

.DESCRIPTION
    Defines the CopilotYolo function (alias: yolo) which runs `copilot --yolo --resume`.
    Errors out gracefully if the copilot CLI is not on PATH.

.EXAMPLE
    PS> yolo

.NOTES
    Requires GitHub Copilot CLI (https://github.com/github/copilot-cli).
#>

function CopilotYolo {
    if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
        Write-Error "copilot CLI not found in PATH"
        return
    }

    copilot --yolo --resume
}

Set-Alias -Name yolo -Value CopilotYolo -Scope Global -Force