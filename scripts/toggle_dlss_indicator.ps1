$path = "HKLM:\SOFTWARE\NVIDIA Corporation\Global\NGXCore";
$name = "ShowDlssIndicator"; 

if (Test-Path $path) {
    $v = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name;

    Set-ItemProperty -Path $path -Name $name -Value $(if ($v -eq 1024) { 0 }else { 1024 });
    Write-Host $("DLSS Indicator " + $(if ($v -eq 1024) { "Disabled." }else { "Enabled." })) 
}
else { Write-Host "Registry path not found." }