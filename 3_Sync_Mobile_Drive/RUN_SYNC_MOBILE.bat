@echo off
color 0A
echo ========================================================
echo  MOBILE SYNC (ADB ENGINE) - EXECUTION MODE
echo ========================================================
echo.
echo  This will SYNC content from PC to Pixel 8.
echo  - Updates modified files.
echo  - Uploads new files.
echo  - DELETES old files from phone (Mirroring).
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Mobile.ps1" -Execute
echo.
echo ========================================================
echo  DONE.
echo ========================================================
pause
