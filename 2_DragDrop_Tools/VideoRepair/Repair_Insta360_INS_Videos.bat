@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Script Name: Repair_Insta360_INS_Videos.bat
rem Description: Repairs recovered .INSV/.MP4 video files using untrunc + ffmpeg.
rem Usage: Repair_Insta360_INS_Videos.bat <ReferenceVideo> [InputFolder]
rem Dependencies: untrunc.exe, ffmpeg.exe
rem ============================================================================

set "REF_VIDEO=%~1"
set "INPUT_DIR=%~2"
if "%INPUT_DIR%"=="" set "INPUT_DIR=."
set "OUTPUT_DIR=%INPUT_DIR%\repaired_videos"

if "%REF_VIDEO%"=="" (
    echo [USAGE] %~nx0 ^<ReferenceVideo^> [InputFolder]
    echo.
    echo Please provide a working reference video from the same camera.
    echo Example: %~nx0 "C:\Videos\good_video.insv" "C:\Videos\Corrupt"
    echo.
    pause
    exit /b
)

if not exist "%REF_VIDEO%" (
    echo [ERROR] Reference video not found: "%REF_VIDEO%"
    pause
    exit /b
)

rem Check dependencies
set "UNTRUNC_CMD=untrunc"
where untrunc >nul 2>nul
if %errorlevel% neq 0 (
    if exist "%~dp0untrunc.exe" (
        set "UNTRUNC_CMD=%~dp0untrunc.exe"
    ) else (
        echo [ERROR] untrunc.exe not found in PATH or next to script.
        pause
        exit /b
    )
)

where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg not found in PATH.
    pause
    exit /b
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo Starting repair...
echo Reference: %REF_VIDEO%
echo Input Dir: %INPUT_DIR%
echo Output Dir: %OUTPUT_DIR%
echo.

for %%F in ("%INPUT_DIR%\*.mp4" "%INPUT_DIR%\*.insv") do (
    rem Skip the reference video itself if it's in the input dir
    if /I not "%%~fF"=="%~f1" (
        echo Processing: %%~nxF
        
        rem 1) untrunc
        rem untrunc creates a file with _fixed suffix in the same folder
        "%UNTRUNC_CMD%" "%REF_VIDEO%" "%%F"
        
        set "FIXED_TEMP=%%~dpnF_fixed%%~xF"
        
        if exist "!FIXED_TEMP!" (
            rem 2) ffmpeg remux
            ffmpeg -y -v error -i "!FIXED_TEMP!" -c copy -map 0 -movflags +faststart "%OUTPUT_DIR%\%%~nF_repaired%%~xF"
            
            if exist "%OUTPUT_DIR%\%%~nF_repaired%%~xF" (
                echo [OK] Repaired: %%~nxF
                del "!FIXED_TEMP!"
            ) else (
                echo [FAIL] ffmpeg remux failed for %%~nxF
            )
        ) else (
            echo [FAIL] untrunc failed for %%~nxF
        )
        echo ---------------------------------------------------
    )
)

echo.
echo Repair completed.
pause
