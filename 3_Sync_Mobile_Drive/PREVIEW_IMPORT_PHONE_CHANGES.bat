@echo off
echo === PREVIEW: Import Phone Changes ===
echo Mostra le differenze tra _iphone\ (copiata da iPhone Files) e la history.
echo Nessuna modifica reale.
echo.
echo PREREQUISITO: hai copiato l'albero da iPhone Files in _iphone\ sul drive.
echo.
set /p DRIVE=Drive root (es. E:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-PhoneChanges.ps1" -DriveRoot "%DRIVE%"
echo.
pause
