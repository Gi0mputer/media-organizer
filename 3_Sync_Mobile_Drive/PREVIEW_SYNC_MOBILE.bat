@echo off
color 0E
echo ========================================================
echo  MOBILE SYNC (ADB ENGINE) - PREVIEW MODE
echo ========================================================
echo.
echo  Checking for changes (No actions will be taken)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Mobile.ps1"
echo.
echo ========================================================
echo  PREVIEW COMPLETE. Run RUN_SYNC_MOBILE.bat to apply.
echo ========================================================
pause
