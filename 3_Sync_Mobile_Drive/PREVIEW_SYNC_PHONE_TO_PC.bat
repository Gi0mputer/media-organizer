@echo off
color 0E
echo ========================================================
echo  PREVIEW SYNC: PHONE -> PC
echo ========================================================
echo.
echo  Checking changes (Read Only)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Mobile.ps1" -Mode Phone2PC
echo.
pause
