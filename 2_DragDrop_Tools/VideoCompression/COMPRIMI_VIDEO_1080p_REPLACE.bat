@echo off
REM ============================================================================
REM COMPRIMI VIDEO - Drag & Drop Entry Point
REM ============================================================================

REM Inject _bin to PATH for portable execution
set "PATH=%~dp0..\..\_bin;%PATH%"

if "%~1"=="" (
    echo Drag and drop video files here.
    pause
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0COMPRIMI_VIDEO_1080p_REPLACE.ps1" %*
