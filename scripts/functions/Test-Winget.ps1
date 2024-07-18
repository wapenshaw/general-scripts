function Test-Winget {
    try {
        winget --version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}