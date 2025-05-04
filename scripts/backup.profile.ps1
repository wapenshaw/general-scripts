
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

Import-Module -Name Microsoft.WinGet.CommandNotFound

Invoke-Expression (&starship init powershell)
function Install-Font {  
    param  
    (  
        [System.IO.FileInfo]$fontFile  
    )  
    try {
        $fontName = $fontFile.Name
        switch ($fontFile.Extension) {  
            ".ttf" { $fontName = "$fontName (TrueType)" }  
            ".otf" { $fontName = "$fontName (OpenType)" }  
        }
        Write-Host "Installing font: $fontFile with font name '$fontName'"
        If (!(Test-Path ("$($env:windir)\Fonts\" + $fontFile.Name))) {  
            Write-Host "Copying font: $fontFile"
            Copy-Item -Path $fontFile.FullName -Destination ("$($env:windir)\Fonts\" + $fontFile.Name) -Force 
        }
        else {  
            Write-Host "Font already exists: $fontFile" 
        }
        If (!(Get-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue)) {  
            Write-Host "Registering font: $fontFile"
            New-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value $fontFile.Name -Force -ErrorAction SilentlyContinue | Out-Null  
        }
        else {  
            Write-Host "Font already registered: $fontFile" 
        }
    }
    catch {            
        Write-Host "Error installing font: $fontFile. " $_.exception.message
    }
}

function Install-Fonts {
    param (
        [string[]]$fontFolders
    )
    
    foreach ($folder in $fontFolders) {
        if (Test-Path -Path $folder) {
            Get-ChildItem -Path $folder -Include *.ttf, *.otf -Recurse | ForEach-Object {
                Install-Font -fontFile $_
            }
        }
        else {
            Write-Host "Font folder not found: $folder" -ForegroundColor Yellow
        }
    }
}

function Open-Explorer {
    explorer.exe .
}

Set-Alias e Open-Explorer
# Added for Azure CLI

Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}
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
function Test-Winget {
    try {
        winget --version > $null 2>&1
        return $true
    }
    catch {
        return $false
    }
}
