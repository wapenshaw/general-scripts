<#
.SYNOPSIS
    Deletes local Git branches whose upstream is gone (status [gone]).

.DESCRIPTION
    Defines the Remove-StaleBranches function (alias: rsb). If the current folder
    is a Git repo, prunes that one. Otherwise scans immediate subfolders for repos
    and prunes each. For each repo it runs `git fetch --prune` and deletes any local
    branch whose upstream reports [gone]. Supports ShouldProcess (use -Confirm or
    -WhatIf from the caller) and a -Force switch for unmerged branches.

.PARAMETER Path
    Folder to scan. Defaults to the current location.
.PARAMETER RemoteName
    Name of the remote to check against. Default: origin.
.PARAMETER Force
    Pass -D to git branch (deletes unmerged branches). Default uses -d.

.EXAMPLE
    PS> rsb
    PS> Remove-StaleBranches -Path C:\code -RemoteName upstream -Force

.NOTES
    No admin required. Alias: rsb.
#>

function Remove-StaleBranches {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Path = (Get-Location).Path,
        [string]$RemoteName = 'origin',
        [Alias('D')]
        [switch]$Force
    )

    function Test-GitRepo {
        param([string]$RepoPath)

        git -C $RepoPath rev-parse --is-inside-work-tree *> $null
        return ($LASTEXITCODE -eq 0)
    }

    function Get-RepoRoot {
        param([string]$RepoPath)

        $root = git -C $RepoPath rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $root) {
            return $root.Trim()
        }

        return $null
    }

    function Clean-StaleBranches {
        param(
            [string]$RepoPath,
            [string]$Remote,
            [switch]$DeleteForce
        )

        $repoRoot = Get-RepoRoot $RepoPath
        if (-not $repoRoot) {
            Write-Warning "Not a git repo: $RepoPath"
            return
        }

        Write-Host ""
        Write-Host "Repository: $repoRoot"

        git -C $repoRoot remote get-url $Remote *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Remote '$Remote' not found in $repoRoot"
            return
        }

        git -C $repoRoot fetch $Remote --prune
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Fetch failed in $repoRoot"
            return
        }

        $currentBranch = (git -C $repoRoot branch --show-current 2>$null).Trim()

        $branchInfo = git -C $repoRoot for-each-ref --format='%(refname:short)|%(upstream:short)|%(upstream:track)' refs/heads
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to enumerate branches in $repoRoot"
            return
        }

        $staleBranches = @()

        foreach ($line in $branchInfo) {
            if (-not $line) { continue }

            $parts = $line -split '\|', 3

            $branch = ''
            $upstream = ''
            $track = ''

            if ($parts.Count -ge 1) { $branch = $parts[0].Trim() }
            if ($parts.Count -ge 2) { $upstream = $parts[1].Trim() }
            if ($parts.Count -ge 3) { $track = $parts[2].Trim() }

            if (-not $branch) { continue }
            if ($branch -eq $currentBranch) { continue }

            # Only consider branches that actually track the specified remote
            if (-not $upstream) { continue }
            if ($upstream -notlike "$Remote/*") { continue }

            # Git reports missing upstreams as [gone]
            if ($track -match '\[gone\]') {
                $staleBranches += [PSCustomObject]@{
                    Branch   = $branch
                    Upstream = $upstream
                }
            }
        }

        if (-not $staleBranches -or $staleBranches.Count -eq 0) {
            Write-Host "No stale branches found."
            return
        }

        Write-Host "Stale branches:"
        foreach ($item in $staleBranches) {
            Write-Host "  $($item.Branch)  (upstream: $($item.Upstream))"
        }

        foreach ($item in $staleBranches) {
            $branch = $item.Branch

            if ($PSCmdlet.ShouldProcess($repoRoot, "Delete stale branch '$branch'")) {
                if ($DeleteForce) {
                    git -C $repoRoot branch -D -- $branch
                }
                else {
                    git -C $repoRoot branch -d -- $branch
                }

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Deleted: $branch"
                }
                else {
                    Write-Warning "Failed to delete branch: $branch"
                }
            }
        }
    }

    if (-not (Test-Path $Path)) {
        Write-Error "Path does not exist: $Path"
        return
    }

    if (Test-GitRepo $Path) {
        Clean-StaleBranches -RepoPath $Path -Remote $RemoteName -DeleteForce:$Force
        return
    }

    $repos = @()

    Get-ChildItem -Path $Path -Directory -Force | ForEach-Object {
        if (Test-GitRepo $_.FullName) {
            $root = Get-RepoRoot $_.FullName
            if ($root -and $root -notin $repos) {
                $repos += $root
            }
        }
    }

    if (-not $repos -or $repos.Count -eq 0) {
        Write-Warning "Current folder is not a git repo, and no git repos were found one level under '$Path'."
        return
    }

    foreach ($repo in $repos) {
        Clean-StaleBranches -RepoPath $repo -Remote $RemoteName -DeleteForce:$Force
    }
}

Set-Alias rsb Remove-StaleBranches