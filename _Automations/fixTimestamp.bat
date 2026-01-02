@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Script Name: fixTimestamp.bat
rem Description: Resets timestamps and moves moov atom to beginning.
rem              Useful for fixing playback issues.
rem              DEFAULT: OVERWRITES ORIGINAL FILES.
rem Usage: Drag and drop files onto this .bat
rem Dependencies: ffmpeg
rem ============================================================================

set "OVERWRITE=1"

rem Check dependencies
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg not found in PATH.
    pause
    exit /b
)

if "%~1"=="" (
    echo Drag and drop one or more MP4/MOV files onto this .bat file.
    echo WARNING: This script will OVERWRITE the original files by default.
    echo.
    pause
    exit /b
)

for %%F in (%*) do (
    echo.
    echo -----------------------------------------
    echo Processing: %%~nxF

    set "INPUT=%%~fF"
    set "NAME=%%~nF"
    set "EXT=%%~xF"

    set "OUTPUT=%%~dpF!NAME!_tmp!EXT!"
    echo Mode: OVERWRITE ACTIVE - Original file will be replaced.

    rem Repair timestamps and index
    ffmpeg -y -v error -i "!INPUT!" -map 0 -c copy -reset_timestamps 1 -movflags +faststart "!OUTPUT!"

    if errorlevel 1 (
        echo [ERROR] Conversion failed for %%~nxF
        if exist "!OUTPUT!" del "!OUTPUT!"
    ) else (
        echo Replacing original file...
        move /Y "!OUTPUT!" "!INPUT!" >nul
        echo [OK] Original file overwritten.
    )
)

echo.
echo Finished.
pause
endlocal
