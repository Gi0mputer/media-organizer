@echo off
color 0A
echo ========================================================
echo  RUN: iCloud Photos -> Inbox (iPhone workflow)
echo ========================================================
echo.
echo  - Copia i file nuovi da iCloud Photos alla Inbox
echo  - Non tocca i file sorgenti iCloud
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-iCloudPhotos-ToInbox.ps1" -Execute
echo.
pause

