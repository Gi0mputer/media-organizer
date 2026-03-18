@echo off
echo === PREVIEW: Enable Phone Mode ===
echo Mostra quali file verrebbero spostati in _iphone\
echo Nessuna modifica reale.
echo.
set /p DRIVE=Drive root (es. F:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable-PhoneMode.ps1" -DriveRoot "%DRIVE%"
echo.
pause
