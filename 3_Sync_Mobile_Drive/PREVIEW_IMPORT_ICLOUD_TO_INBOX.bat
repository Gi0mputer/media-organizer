@echo off
color 0E
echo ========================================================
echo  PREVIEW: iCloud Photos -> Inbox (iPhone workflow)
echo ========================================================
echo.
echo  - Scansiona i file iCloud Photos
echo  - Pianifica copia in Inbox (nessuna scrittura)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-iCloudPhotos-ToInbox.ps1"
echo.
pause

