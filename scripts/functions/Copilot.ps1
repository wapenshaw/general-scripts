function CopilotYolo {
    if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
        Write-Error "copilot CLI not found in PATH"
        return
    }

    copilot --yolo --resume
}

Set-Alias yolo CopilotYolo