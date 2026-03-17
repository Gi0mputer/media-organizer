@echo off
color 0E
echo ========================================================
echo  PREVIEW: Publish _gallery -> iCloud Uploads
echo ========================================================
echo.
echo  Uso:
echo    - Trascina una cartella evento (o _gallery) su questo .bat
echo    - Oppure esegui: PREVIEW_PUBLISH_GALLERY_TO_ICLOUD.bat "E:\2026\Evento"
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publish-Gallery-ToiCloudUploads.ps1" %*
echo.
pause

