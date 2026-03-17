@echo off
echo === PREVIEW: Enable Phone Mode (DELTA) ===
echo Mostra solo i file NUOVI o MODIFICATI dall'ultimo sync.
echo Richiede history esistente in _sys\_iphone_history.json.
echo Nessuna modifica reale.
echo.
set /p DRIVE=Drive root (es. F:\):
if "%DRIVE%"=="" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable-PhoneMode.ps1" -DriveRoot "%DRIVE%" -DeltaOnly
echo.
pause
