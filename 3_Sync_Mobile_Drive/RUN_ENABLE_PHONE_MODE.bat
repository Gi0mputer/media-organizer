@echo off
echo === RUN: Enable Phone Mode ===
echo Sposta i file phone-worthy in _iphone\ nella root del drive.
echo I file in _pc\ rimangono al loro posto.
echo Il manifest viene salvato prima di qualsiasi move.
echo.
set /p DRIVE=Drive root (es. F:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable-PhoneMode.ps1" -DriveRoot "%DRIVE%" -Execute
echo.
pause
