@echo off
rem ============================================================================
rem Wrapper: Launches PowerShell compression script with drag&drop files
rem ============================================================================

if "%~1"=="" (
    echo Drag and drop video files here.
    pause
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0COMPRIMI_VIDEO_1080p_REPLACE.ps1" %*
