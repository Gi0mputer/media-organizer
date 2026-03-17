@echo off
echo === PREVIEW: Restore PC Mode ===
echo Mostra quali file verrebbero rimessi nella posizione originale.
echo Nessuna modifica reale.
echo.
set /p DRIVE=Drive root (es. F:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-PCMode.ps1" -DriveRoot "%DRIVE%"
echo.
pause
