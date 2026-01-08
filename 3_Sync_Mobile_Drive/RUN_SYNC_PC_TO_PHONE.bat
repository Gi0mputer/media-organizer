@echo off
color 0A
echo ========================================================
echo  MOBILE SYNC: PC -> PHONE (Mirroring)
echo ========================================================
echo.
echo  MASTER: PC (E: / D:)
echo  TARGET: Phone (Pixel 8)
echo.
echo  - New files on PC  -> Pushed to Phone
echo  - Deleted on PC    -> Deleted from Phone
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Mobile.ps1" -Mode PC2Phone -Execute
echo.
pause
