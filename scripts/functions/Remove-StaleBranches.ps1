function Remove-StaleLocalBranches {
    git fetch --all --prune

    $remoteBranchesCount = (git branch -r).Count
    Write-Host "Fetched remote branches ($remoteBranchesCount)"

    $localBranches = git branch --merged | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne 'master' -and $_ -ne 'main' -and $_ -notlike '*HEAD' }
    $localBranchesCount = $localBranches.Count
    Write-Host "Local branches ($localBranchesCount):"
    Write-Host ($localBranches -Join ", ")

    foreach ($branch in $localBranches) {
        $branchName = $branch.Replace("* ", "").Trim()
        if (-not (git branch -r | Where-Object { $_ -match "origin/$branchName" }).Count) {
            Write-Host "Deleting local branch: $branchName"
            git branch -d $branchName
        }
    }
}

Set-Alias -Name git-stale-prune -Value Remove-StaleLocalBranches