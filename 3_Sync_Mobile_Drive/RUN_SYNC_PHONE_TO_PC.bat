@echo off
color 0B
echo ========================================================
echo  MOBILE SYNC: PHONE -> PC (Import Changes)
echo ========================================================
echo.
echo  MASTER: Phone (Pixel 8)
echo  TARGET: PC (E: / D:)
echo.
echo  - New files on Phone  -> Pulled to PC
echo  - Deleted on Phone    -> Deleted from PC
echo.
echo  WARNING: This will update your PC folders.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Sync-Mobile.ps1" -Mode Phone2PC -Execute
echo.
pause
