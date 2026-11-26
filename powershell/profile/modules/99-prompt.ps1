<#
.SYNOPSIS
  Starship prompt initialisation. Loaded LAST, after all other modules.
.DESCRIPTION
  Module 99 of the modular PowerShell profile. Mirrors zsh's prompt.zsh
  placement — the prompt must capture all env vars, PATH additions, and
  functions set by earlier modules.

  Startup cost: `starship init powershell` only prints a stub that runs starship a
  second time (`--print-full-init`) and evaluates the result. The full script is cached
  under %LOCALAPPDATA%\PowerShellSetup\cache and regenerated when starship.exe changes.

  Per-prompt cost: starship's git_branch and git_status modules each spawn git, which
  is slow under endpoint security. This module exports the current branch, read straight
  from .git/HEAD, as STARSHIP_GIT_BRANCH on every prompt. A starship.toml that disables
  git_branch/git_status can render it with the env_var module (see README.md).
#>

if ($env:TERM -eq 'dumb' -or $env:PS_DISABLE_PROMPT -eq '1') { return }

# Probe PATH directly: Get-Command is ~90 ms for a command that is not installed.
$starshipExe = $null
$starshipName = if ($IsWindows) { 'starship.exe' } else { 'starship' }
foreach ($dir in $env:PATH.Split([IO.Path]::PathSeparator)) {
    if (-not $dir) { continue }
    $candidate = [IO.Path]::Combine($dir, $starshipName)
    if ([IO.File]::Exists($candidate)) { $starshipExe = $candidate; break }
}
if (-not $starshipExe) { return }

try {
    $initCache = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PowerShellSetup/cache/starship-init.ps1'
    $exeInfo = [IO.FileInfo]::new($starshipExe)
    $initKey = "# starship-init-cache: $starshipExe|$($exeInfo.Length)|$($exeInfo.LastWriteTimeUtc.Ticks)"

    # Read the cache once and evaluate that same string: re-opening the path after the
    # key check would let a concurrent launch (e.g. a different starship on its PATH)
    # replace the file between validation and execution.
    $initScript = $null
    if ([IO.File]::Exists($initCache)) {
        try {
            $cached = [IO.File]::ReadAllText($initCache)
            $headerEnd = $cached.IndexOf("`n")
            if ($headerEnd -ge 0 -and $cached.Substring(0, $headerEnd) -ceq $initKey) {
                $initScript = $cached.Substring($headerEnd + 1)
            }
        } catch { $initScript = $null }
    }

    if ($initScript) {
        Invoke-Expression $initScript
    } else {
        $initScript = (& $starshipExe init powershell --print-full-init) -join "`n"
        if ($LASTEXITCODE -ne 0 -or -not $initScript) { throw "starship init exited with code $LASTEXITCODE" }
        $tmp = "$initCache.$PID.tmp"
        try {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($initCache))
            [IO.File]::WriteAllText($tmp, "$initKey`n$initScript`n")
            [IO.File]::Move($tmp, $initCache, $true)
        } catch {
            # Cache is an optimisation only; evaluate the fresh script regardless.
            Remove-Item -LiteralPath $tmp -Force -ErrorAction Ignore
        }
        Invoke-Expression $initScript
    }
} catch {
    Write-Warning "99-prompt: starship init failed: $($_.Exception.Message)"
    return
}

function global:Get-FastGitBranch {
    <#
    .SYNOPSIS
      Returns the current git branch (or short detached hash) without starting git.
    .DESCRIPTION
      Walks up from the current directory to the first .git directory or gitdir file
      (worktrees and submodules) and parses HEAD. Returns $null outside a repository.
    #>
    if ($PWD.Provider.Name -ne 'FileSystem') { return $null }
    try {
        $dir = $PWD.ProviderPath
        while ($dir) {
            $dotGit = [IO.Path]::Combine($dir, '.git')
            $gitDir = $null
            if ([IO.Directory]::Exists($dotGit)) {
                $gitDir = $dotGit
            } elseif ([IO.File]::Exists($dotGit)) {
                $pointer = [IO.File]::ReadAllText($dotGit).Trim()
                if ($pointer.StartsWith('gitdir:')) {
                    $gitDir = [IO.Path]::GetFullPath($pointer.Substring(7).Trim(), $dir)
                }
            }
            if ($gitDir) {
                $headPath = [IO.Path]::Combine($gitDir, 'HEAD')
                if (-not [IO.File]::Exists($headPath)) { return $null }
                $head = [IO.File]::ReadAllText($headPath).Trim()
                if ($head.StartsWith('ref:')) {
                    $ref = $head.Substring(4).Trim()
                    return $ref.StartsWith('refs/heads/') ? $ref.Substring(11) : $ref
                }
                return $head.Length -ge 7 ? "($($head.Substring(0, 7)))" : $null
            }
            $dir = [IO.Path]::GetDirectoryName($dir)
        }
    } catch { }
    return $null
}

# Starship runs this hook inside its prompt function, after it has captured $? and
# $LASTEXITCODE, so it cannot disturb the status display. A $null value removes the variable.
function global:Invoke-Starship-PreCommand {
    [Environment]::SetEnvironmentVariable('STARSHIP_GIT_BRANCH', (Get-FastGitBranch))
}
