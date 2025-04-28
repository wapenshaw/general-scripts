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