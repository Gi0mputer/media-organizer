@echo off
echo === RUN: Migrazione cartelle insta360 ===
echo ATTENZIONE: operazione reale. Assicurati di aver fatto il PREVIEW prima.
echo.
set /p CONFIRM=Digita SI per continuare:
if /i not "%CONFIRM%"=="SI" (
    echo Annullato.
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Migrate-Insta360.ps1"
echo.
pause
