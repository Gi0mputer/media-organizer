@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Script Name: RiparaMini5.bat
rem Description: Repairs DJI videos or LosslessCut outputs.
rem              - Resets timestamps to fix startup lag/blocks.
rem              - Moves moov atom to beginning (faststart).
rem              - Lossless copy (no re-encoding).
rem Usage: Drag and drop files onto this .bat
rem        Or run with /overwrite flag as first argument to overwrite originals.
rem Dependencies: ffmpeg
rem ============================================================================

set "OVERWRITE=0"

rem Check for overwrite flag
if /I "%~1"=="/overwrite" (
    set "OVERWRITE=1"
    shift
)

rem Check dependencies
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg not found in PATH.
    pause
    exit /b
)

if "%~1"=="" (
    echo Drag and drop one or more MP4/MOV files onto this .bat file.
    echo Current Configuration: OVERWRITE=%OVERWRITE%
    echo.
    echo Usage: %~nx0 [/overwrite] [files...]
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

    if "%OVERWRITE%"=="1" (
        set "OUTPUT=%%~dpF!NAME!_tmp!EXT!"
        echo Mode: OVERWRITE ACTIVE - Original file will be replaced.
    ) else (
        set "OUTPUT=%%~dpF!NAME!_fixed!EXT!"
        echo Mode: OVERWRITE OFF - Creating new file: !OUTPUT!
    )

    rem Repair timestamps and index
    ffmpeg -y -v error -i "!INPUT!" -map 0 -c copy -reset_timestamps 1 -movflags +faststart "!OUTPUT!"

    if errorlevel 1 (
        echo [ERROR] Conversion failed for %%~nxF
        if exist "!OUTPUT!" del "!OUTPUT!"
    ) else (
        if "%OVERWRITE%"=="1" (
            echo Replacing original file...
            move /Y "!OUTPUT!" "!INPUT!" >nul
            echo [OK] Original file overwritten.
        ) else (
            echo [OK] Created: !OUTPUT!
        )
    )
)

echo.
echo Finished.
pause
endlocal
