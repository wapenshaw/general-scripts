$A = "E:\Downloads\GOLD_Update_EGPM"
$B = "E:\Downloads\GOLD_Update_EGPM_2"

$filesA = Get-ChildItem $A -File -Recurse | ForEach-Object {
    [PSCustomObject]@{
        Path = $_.FullName.Substring($A.Length)
        Size = $_.Length
    }
}

$filesB = Get-ChildItem $B -File -Recurse | ForEach-Object {
    [PSCustomObject]@{
        Path = $_.FullName.Substring($B.Length)
        Size = $_.Length
    }
}

$diff = Compare-Object $filesA $filesB -Property Path, Size

if ($diff) {
    $diff | Format-Table -AutoSize
    Write-Host "`nDifferent files found." -ForegroundColor Red
}
else {
    Write-Host "File lists and sizes match. Now verify hashes..." -ForegroundColor Yellow

    $hashA = Get-ChildItem $A -File -Recurse | Get-FileHash -Algorithm SHA256 |
        ForEach-Object {
            $_.Hash + "|" + $_.Path.Substring($A.Length)
        }

    $hashB = Get-ChildItem $B -File -Recurse | Get-FileHash -Algorithm SHA256 |
        ForEach-Object {
            $_.Hash + "|" + $_.Path.Substring($B.Length)
        }

    if (Compare-Object $hashA $hashB) {
        Write-Host "Folders are NOT identical." -ForegroundColor Red
    }
    else {
        Write-Host "Folders are IDENTICAL." -ForegroundColor Green
    }
}