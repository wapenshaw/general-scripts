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
