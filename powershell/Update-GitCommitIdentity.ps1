<#
.SYNOPSIS
    Rewrites the author/committer name and email of every commit in a Git repo.

.DESCRIPTION
    Uses git filter-branch with an env-filter to override GIT_AUTHOR_* and GIT_COMMITTER_*
    on every commit, then optionally force-pushes the result. Useful for fixing commits
    that were made with the wrong identity (typo, machine switch, work/personal mixup).

.PARAMETER NewEmail
    Email to apply to every commit.
.PARAMETER NewName
    Name to apply to every commit.
.PARAMETER RepositoryPath
    Path to the repository. Defaults to the current directory.

.EXAMPLE
    PS> pwsh -File .\Update-GitCommitIdentity.ps1 -NewName 'Alice' -NewEmail 'alice@example.com' -RepositoryPath 'C:\code\repo'

.NOTES
    Rewriting history is destructive. Coordinate with collaborators before force-pushing.
#>

# Script to update all Git commit emails in a repository
param(
    [Parameter(Mandatory = $true)]
    [string]$NewEmail,
    
    [Parameter(Mandatory = $true)]
    [string]$NewName,
    
    [Parameter(Mandatory = $false)]
    [string]$RepositoryPath = "."
)

function Test-GitRepository {
    $gitDir = Join-Path $RepositoryPath ".git"
    return Test-Path $gitDir
}

function Update-GitCommits {
    try {
        # Change to repository directory
        Push-Location $RepositoryPath

        # Verify we're in a git repository
        if (-not (Test-GitRepository)) {
            throw "Not a git repository. Please run this script from a git repository or provide a valid path."
        }

        # Create the filter-branch command
        $filterCommand = @"
        export GIT_COMMITTER_NAME="$NewName"
        export GIT_COMMITTER_EMAIL="$NewEmail"
        export GIT_AUTHOR_NAME="$NewName"
        export GIT_AUTHOR_EMAIL="$NewEmail"
"@

        # Run git filter-branch
        Write-Host "Updating commits with new email and name..." -ForegroundColor Yellow
        git filter-branch --env-filter $filterCommand --tag-name-filter cat -- --branches --tags

        # Force push changes
        Write-Host "Would you like to force push the changes to remote? (y/n)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -eq 'y') {
            Write-Host "Force pushing changes..." -ForegroundColor Yellow
            git push --force --tags origin 'refs/heads/*'
        }

        Write-Host "Process completed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
    finally {
        # Return to original directory
        Pop-Location
    }
}

# Run the script
Update-GitCommits