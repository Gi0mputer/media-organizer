@echo off
echo === RUN: Enable Phone Mode (DELTA) ===
echo Sposta in _iphone\ solo i file NUOVI o MODIFICATI dall'ultimo sync.
echo Richiede history esistente in _sys\_iphone_history.json.
echo.
set /p DRIVE=Drive root (es. E:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable-PhoneMode.ps1" -DriveRoot "%DRIVE%" -Execute -DeltaOnly
echo.
pause
