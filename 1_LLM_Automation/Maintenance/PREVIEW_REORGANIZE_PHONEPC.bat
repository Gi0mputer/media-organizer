@echo off
echo === PREVIEW: Riorganizzazione paradigma phone/pc ===
echo Nessuna modifica reale. Solo anteprima.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Reorganize-PhonePc.ps1" -DryRun
echo.
pause
