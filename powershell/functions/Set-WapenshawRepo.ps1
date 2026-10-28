<#
.SYNOPSIS
    Configures a personal 'wapenshaw' Git repository with proper identity, SSH signing, and remote URL.

.DESCRIPTION
    By default, targets your Mac ('lanaya') over SSH and configures the specified repository in ~/Code.
    Sets user.name, user.email, user.signingkey, commit.gpgsign, gpg.format, and updates origin to use
    the 'github-personal' SSH host alias.

    Optionally clones the repository on the remote machine if -Clone is specified, or runs locally
    against the current repository if -Local is specified.

.PARAMETER RepoName
    The name of the repository (e.g. 'herdr-theme-picker' or 'wapenshaw/herdr-theme-picker').

.PARAMETER RemoteHost
    The SSH host to target. Defaults to 'lanaya'.

.PARAMETER RemoteDir
    The base directory for repositories on the remote host. Defaults to '~/Code'.

.PARAMETER Clone
    If specified, clones the repository first via 'git clone git@github-personal:wapenshaw/<RepoName>.git'
    into the remote directory before applying configuration.

.PARAMETER Local
    If specified, applies the configuration to the current local repository instead of SSH'ing to the remote host.

.EXAMPLE
    Set-WapenshawRepo herdr-theme-picker

.EXAMPLE
    swr my-new-plugin -Clone

.EXAMPLE
    Set-WapenshawRepo -Local
#>

function Set-WapenshawRepo {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = $false)]
        [string]$RepoName,

        [Parameter(Mandatory = $false)]
        [string]$RemoteHost = "lanaya",

        [Parameter(Mandatory = $false)]
        [string]$RemoteDir = "~/Code",

        [Parameter(Mandatory = $false)]
        [switch]$Clone,

        [Parameter(Mandatory = $false)]
        [switch]$Local
    )

    $UserName   = "wapenshaw"
    $UserEmail  = "thescarletcars@gmail.com"
    $GithubOrg  = "wapenshaw"

    # Clean RepoName if a full git/https URL or org/repo was passed
    if ($RepoName) {
        $RepoName = $RepoName -replace '^.*[/:]([^/]+?)(?:\.git)?$', '$1'
    }

    if ($Local) {
        # Local configuration (Windows)
        if (-not (Test-Path ".git")) {
            Write-Error "Not a git repository. Run this command inside a git repo or provide -RemoteHost."
            return
        }

        if (-not $RepoName) {
            $originUrl = git remote get-url origin 2>$null
            if ($originUrl) {
                $RepoName = $originUrl -replace '^.*[/:]([^/]+?)(?:\.git)?$', '$1'
            } else {
                $RepoName = (Get-Item .).Name
            }
        }

        $signingKey = "C:/Users/tHeSiD/.ssh/id_ed25519_personal.pub"
        if (-not (Test-Path $signingKey)) {
            $signingKey = "$HOME/.ssh/id_ed25519_personal.pub"
        }

        Write-Host "Configuring local repository '$RepoName' for $UserName..." -ForegroundColor Cyan

        git config user.name "$UserName"
        git config user.email "$UserEmail"
        git config user.signingkey "$signingKey"
        git config commit.gpgsign true
        git config gpg.format ssh
        git remote set-url origin "git@github-personal:${GithubOrg}/${RepoName}.git"

        Write-Host "`n✓ Local repository configured successfully:" -ForegroundColor Green
        git config --get-regexp "^user\.|^commit\.|^gpg\.|^remote\.origin\.url"
        return
    }

    # Remote configuration on Mac (lanaya)
    if (-not $RepoName) {
        Write-Host "Fetching repository list from ${RemoteHost}:${RemoteDir}..." -ForegroundColor Yellow
        $remoteList = ssh $RemoteHost "ls -1 $RemoteDir" 2>$null
        if ($remoteList) {
            Write-Host "Available repositories in $RemoteDir on $RemoteHost`:" -ForegroundColor Cyan
            $remoteList | ForEach-Object { Write-Host "  - $_" }
        }
        $RepoName = Read-Host "`nEnter repository name to configure"
        if (-not $RepoName) {
            Write-Error "Repository name is required."
            return
        }
        $RepoName = $RepoName -replace '^.*[/:]([^/]+?)(?:\.git)?$', '$1'
    }

    $remoteRepoPath = "$RemoteDir/$RepoName"
    $sshRemote = "git@github-personal:${GithubOrg}/${RepoName}.git"

    Write-Host "Connecting to $RemoteHost..." -ForegroundColor Cyan

    if ($Clone) {
        Write-Host "Cloning $sshRemote into $remoteRepoPath on $RemoteHost..." -ForegroundColor Yellow
        $cloneCmd = "TARGET_DIR=`$(eval echo `"$RemoteDir`") && mkdir -p `"`$TARGET_DIR`" && cd `"`$TARGET_DIR`" && git clone `"$sshRemote`" `"$RepoName`""
        ssh $RemoteHost $cloneCmd
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to clone $RepoName on $RemoteHost."
            return
        }
    }

    # Configure Git on remote Mac
    $configScript = @"
TARGET_DIR=`$(eval echo "$remoteRepoPath")
if [ ! -d "`$TARGET_DIR/.git" ]; then
    echo "ERROR: Directory `$TARGET_DIR is not a git repository."
    exit 1
fi
cd "`$TARGET_DIR"

git config user.name "$UserName"
git config user.email "$UserEmail"
git config user.signingkey ~/.ssh/id_ed25519_personal.pub
git config commit.gpgsign true
git config gpg.format ssh
git remote set-url origin "$sshRemote"

echo "=== Configuration for $RepoName on `$(hostname) ==="
echo "user.name     : `$(git config user.name)"
echo "user.email    : `$(git config user.email)"
echo "signingkey    : `$(git config user.signingkey)"
echo "commit.gpgsign: `$(git config commit.gpgsign)"
echo "gpg.format    : `$(git config gpg.format)"
echo "remote.origin : `$(git remote get-url origin)"
"@

    $configScript | ssh $RemoteHost "bash -s"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ $RepoName on $RemoteHost configured successfully!" -ForegroundColor Green
    } else {
        Write-Error "Failed to configure $RepoName on $RemoteHost."
    }
}

Set-Alias -Name 'swr' -Value 'Set-WapenshawRepo' -Description 'Configure personal wapenshaw git repo on Mac lanaya or locally'
