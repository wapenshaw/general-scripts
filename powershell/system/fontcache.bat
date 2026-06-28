@echo off

:: Stop and disable "Windows Font Cache Service" service
set RETRY=0
:FontCache
sc stop "FontCache" >nul 2>&1
sc config "FontCache" start=disabled >nul 2>&1
sc query FontCache | findstr /I /C:"STOPPED" >nul 2>&1
if %errorlevel%==0 goto FontCacheStopped
set /a RETRY+=1
if %RETRY% GEQ 10 (
    echo ERROR: FontCache service did not stop after 10 attempts. Aborting.
    exit /b 1
)
timeout /t 3 /nobreak >nul
goto FontCache
:FontCacheStopped


:: Grant access rights to current user for "%WinDir%\ServiceProfiles\LocalService" folder and contents
icacls "%WinDir%\ServiceProfiles\LocalService" /grant "%UserName%":F /C /T /Q


:: Delete font cache
del /A /F /Q "%WinDir%\ServiceProfiles\LocalService\AppData\Local\FontCache\*FontCache*"

del /A /F /Q "%WinDir%\System32\FNTCACHE.DAT"


:: Enable and start "Windows Font Cache Service" service
sc config "FontCache" start=auto
sc start "FontCache"