<#
.SYNOPSIS
  Use Git for Windows' real git.exe instead of the cmd\git.exe launcher.
.DESCRIPTION
  Module 05 of the modular PowerShell profile. Git for Windows puts a small
  launcher (cmd\git.exe) on PATH that starts the real git (ucrt64\bin\git.exe or
  mingw64\bin\git.exe), so every git call creates two processes. On machines with
  endpoint security each process costs tens of milliseconds, and measured spawns
  were about 22% faster calling the real binary.

  Git\cmd is normally on the machine PATH, which a user PATH entry cannot
  override, and the whole ucrt64\bin folder would shadow other tools (curl uses a
  different CA store than System32's). So only this session's PATH is changed:
  the real bin folder goes immediately before Git\cmd, after System32. Nothing is
  done if Git is not installed in that layout.
#>

$gitCmd = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($gitCmd -and (Split-Path $gitCmd.Source -Leaf) -eq 'git.exe' -and (Split-Path $gitCmd.Source -Parent) -match '\\Git\\cmd$') {
    $gitRoot = Split-Path (Split-Path $gitCmd.Source -Parent) -Parent
    $gitReal = @('ucrt64', 'mingw64', 'clangarm64') |
        ForEach-Object { Join-Path $gitRoot "$_\bin" } |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ 'git.exe') } |
        Select-Object -First 1
    if ($gitReal) {
        $parts = $env:PATH -split ';' | Where-Object { $_ }
        if ($parts -notcontains $gitReal) {
            $at = [array]::IndexOf($parts, (Split-Path $gitCmd.Source -Parent))
            if ($at -ge 0) {
                $env:PATH = (@($parts[0..($at - 1)]) + $gitReal + @($parts[$at..($parts.Count - 1)]) | Where-Object { $_ }) -join ';'
            }
        }
    }
    Remove-Variable gitRoot, gitReal, parts, at -ErrorAction SilentlyContinue
}
Remove-Variable gitCmd -ErrorAction SilentlyContinue
