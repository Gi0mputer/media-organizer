@echo off
echo === RUN: Import Phone Changes ===
echo Importa da _iphone\ le modifiche fatte su iPhone:
echo   - File nuovi    -^> copiati nella posizione originale su PC
echo   - File modificati -^> aggiornano la versione su PC
echo   - File eliminati  -^> spostati in Evento\_pc\_trash\
echo.
echo PREREQUISITO: hai copiato l'albero da iPhone Files in _iphone\ sul drive.
echo.
set /p DRIVE=Drive root (es. E:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-PhoneChanges.ps1" -DriveRoot "%DRIVE%" -Execute
echo.
pause
