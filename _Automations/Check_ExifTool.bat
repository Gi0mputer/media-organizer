@echo off
setlocal

echo *** EXIFTOOL CHECK ***
echo Script: %~f0
echo.

set "TOOL_NAME=exiftool.exe"
set "FOUND=0"

rem Check next to script
set "TOOL_NEAR=%~dp0%TOOL_NAME%"
if exist "%TOOL_NEAR%" (
    echo [OK] Found next to script:
    echo   "%TOOL_NEAR%"
    "%TOOL_NEAR%" -ver
    echo.
    set "FOUND=1"
)

rem Check in PATH
where %TOOL_NAME% >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] Found in PATH:
    for /f "delims=" %%I in ('where %TOOL_NAME%') do echo   "%%I"
    %TOOL_NAME% -ver
    echo.
    set "FOUND=1"
) else (
    echo [INFO] Not found in PATH.
)

if "%FOUND%"=="0" (
    echo [ERROR] %TOOL_NAME% not found in current directory or PATH.
    echo Please install ExifTool or place it next to this script.
)

echo.
pause
