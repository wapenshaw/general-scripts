# Function to remove local Git branches that are not on the remote anymore
function Remove-StaleBranches {
    # Fetch the latest changes from the remote and prune deleted branches
    git fetch --prune
 
    # Get the list of all local branches
    $localBranches = git branch | ForEach-Object { $_.Trim().TrimStart('*').Trim() }
 
    # Get the list of all remote branches
    $remoteBranches = git branch -r | ForEach-Object { $_.Trim().Replace('origin/', '') }
 
    # Identify stale branches (local branches not in remote branches)
    $staleBranches = $localBranches | Where-Object { $remoteBranches -notcontains $_ }
 
    # Check if there are any stale branches
    if (-not $staleBranches) {
        Write-Output "No stale branches found."
        return
    }
 
    # Remove each stale branch
    foreach ($branch in $staleBranches) {
        git branch -D $branch
        Write-Output "Removed branch: $branch"
    }
}
 
# Alias for the Function to remove local Git branches that are not on the remote anymore
Set-Alias rsb Remove-StaleBranches