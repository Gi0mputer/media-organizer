@echo off
echo === PREVIEW: Migrazione cartelle insta360 ===
echo Nessuna modifica reale. Solo anteprima.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Migrate-Insta360.ps1" -DryRun
echo.
pause
