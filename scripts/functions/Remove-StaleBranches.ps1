function Remove-StaleLocalBranches {
    git fetch --all --prune
    $remoteBranches = git branch -r | ForEach-Object { $_.Trim() }
    $localBranches = git branch | ForEach-Object { $_.Trim() }

    foreach ($branch in $localBranches) {
        if ($branch -ne "master" -and $branch -ne "main" -and $branch -ne "* $(git symbolic-ref --short HEAD)") {
            $remoteBranchExists = $remoteBranches -contains ("origin/" + $branch)
            if (-not $remoteBranchExists) {
                Write-Host "Deleting local branch: $branch"
                git branch -d $branch
            }
        }
    }
}

Set-Alias -Name git-remote-del -Value Remove-StaleLocalBranches