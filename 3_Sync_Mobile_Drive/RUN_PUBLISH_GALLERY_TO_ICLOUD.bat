@echo off
color 0A
echo ========================================================
echo  RUN: Publish _gallery -> iCloud Uploads
echo ========================================================
echo.
echo  Uso:
echo    - Trascina una cartella evento (o _gallery) su questo .bat
echo    - Oppure esegui: RUN_PUBLISH_GALLERY_TO_ICLOUD.bat "E:\2026\Evento"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publish-Gallery-ToiCloudUploads.ps1" %* -Execute
echo.
pause

