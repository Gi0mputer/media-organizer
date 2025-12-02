@echo off
setlocal
set "SCRIPT=%~dp0Converti-4K-a-1080p.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" %*
endlocal
