@echo off
echo === RUN: Restore PC Mode ===
echo Ripristina i file da _iphone\ alle posizioni originali.
echo Legge il manifest _iphone_manifest.json dalla root del drive.
echo.
set /p DRIVE=Drive root (es. E:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-PCMode.ps1" -DriveRoot "%DRIVE%" -Execute
echo.
pause
