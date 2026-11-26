<#
.SYNOPSIS
  Prefer the standalone winget kubectl over the copy bundled with Docker Desktop.
.DESCRIPTION
  Module 05 of the modular PowerShell profile. Docker Desktop's installer puts
  C:\Program Files\Docker\Docker\resources\bin on the Machine PATH, and Machine
  entries come before User entries, so a winget (user scope) kubectl never wins
  and removing the Docker entry needs admin. Only this session's PATH is changed:
  the winget Kubernetes.kubectl package folder is moved to the front. Nothing is
  done when that package is not installed.
#>

$wingetPackages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$kubectlDir = if (Test-Path -LiteralPath $wingetPackages) {
    [System.IO.Directory]::GetDirectories($wingetPackages, 'Kubernetes.kubectl_*') |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'kubectl.exe') } |
        Select-Object -First 1
}
if ($kubectlDir -and ($env:PATH -notlike "$kubectlDir;*")) {
    $env:PATH = "$kubectlDir;$env:PATH"
}
Remove-Variable wingetPackages, kubectlDir -ErrorAction SilentlyContinue
