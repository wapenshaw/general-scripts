function gverify {
    Write-Host "== Git Verification ==" -ForegroundColor Cyan

    # 1. Ensure inside repo
    if (-not ((git rev-parse --is-inside-work-tree) 2>$null)) {
        Write-Host "Not a git repository." -ForegroundColor Red
        return
    }

    # 2. Basic identity
    $email = git config user.email
    $name = git config user.name

    Write-Host "`n[Identity]"
    Write-Host "Name : $name"
    Write-Host "Email: $email"

    # 3. Remote check
    $remote = git remote get-url origin 2>$null
    Write-Host "`n[Remote]"
    Write-Host $remote

    if ($remote -match "github-assurant") {
        Write-Host "Context: Assurant ✔" -ForegroundColor Green
    }
    elseif ($remote -match "github-personal") {
        Write-Host "Context: Personal ✔" -ForegroundColor Green
    }
    elseif ($remote -match "ado-pinion") {
        Write-Host "Context: Pinion ✔" -ForegroundColor Green
    }
    else {
        Write-Host "Unknown or incorrect remote ❌" -ForegroundColor Red
    }

    # 4. Signing config
    $sign = git config commit.gpgsign
    $key = git config user.signingkey
    $fmt = git config gpg.format

    Write-Host "`n[Signing]"
    Write-Host "Signing enabled : $sign"
    Write-Host "Signing key     : $key"
    Write-Host "GPG format      : $fmt"

    if ($sign -ne "true") {
        Write-Host "Signing NOT enabled ❌" -ForegroundColor Red
        Write-Host "  → Check includeIf path for this repo's location" -ForegroundColor Yellow
    }
    elseif (-not $key) {
        Write-Host "Signing enabled but NO KEY set ❌" -ForegroundColor Red
    }
    else {
        Write-Host "Signing configured ✔" -ForegroundColor Green
    }
    # After your signing check block
    $localOverrides = git config --local --list 2>$null
    if ($localOverrides -match "user\.|commit\.gpgsign|signingkey") {
        Write-Host "`n[Warning] Local repo config is overriding globals:" -ForegroundColor Yellow
        $localOverrides | Where-Object { $_ -match "user\.|commit\.gpgsign|signingkey" } | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Yellow
        }
    }
    # 5. Last commit signature
    Write-Host "`n[Last Commit Signature]"
    $sig = git log -1 --show-signature 2>$null

    if ($sig -match 'Good "git" signature') {
        Write-Host "Signature: VALID ✔" -ForegroundColor Green
    }
    elseif ($sig -match "No signature") {
        Write-Host "Signature: MISSING ❌" -ForegroundColor Red
    }
    else {
        Write-Host "Signature: UNKNOWN ⚠"
    }

    # 6. SSH agent keys
    Write-Host "`n[SSH Agent Keys]"
    ssh-add -l

    # 7. SSH identity test (based on remote)
    Write-Host "`n[SSH Identity Test]"
    if ($remote -match "github-assurant") {
        ssh -T git@github-assurant
    }
    elseif ($remote -match "github-personal") {
        ssh -T git@github-personal
    }
    elseif ($remote -match "ado-pinion") {
        ssh -T git@ado-pinion
    }

    Write-Host "`n== Done ==" -ForegroundColor Cyan
}