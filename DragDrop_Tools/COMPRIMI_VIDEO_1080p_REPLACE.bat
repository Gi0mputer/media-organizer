@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Script Name: COMPRIMI_VIDEO_1080p_REPLACE.bat
rem Description: Compresses video to 1920px (long edge) using HEVC (H.265).
rem              - REPLACES ORIGINAL if successful.
rem              - Handles videos with NO AUDIO (Drone footage).
rem Usage: Drag and drop files onto this .bat
rem ============================================================================

rem ===== CONFIG =====
set "SUFFIX= (small)"
set "MAX_LONG=1920"
set "HEVC_CQ=24"
set "PRESET=p5"
rem ===============

if "%~1"=="" (
    echo Drag and drop files here.
    echo WARNING: Originals DELETED on success!
    pause
    exit /b
)

:NEXT_FILE
if "%~1"=="" goto FINISH
call :PROCESS "%~1"
shift
goto NEXT_FILE

:FINISH
echo.
echo All operations completed.
pause
exit /b

:PROCESS
set "SRC=%~1"
set "OUT=%~dpn1%SUFFIX%%~x1"

echo.
echo -------------------------------------------------------------------------
echo Processing: "%SRC%"

rem Check for Audio Stream using ffprobe
set "HAS_AUDIO=0"
ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "%SRC%" >nul 2>&1
if not errorlevel 1 set "HAS_AUDIO=1"

rem Build Audio Arguments
if "%HAS_AUDIO%"=="1" (
    echo [INFO] Audio track detected. Converting to AAC...
    set "AUDIO_ARGS=-c:a aac -b:a 128k"
) else (
    echo [INFO] No Audio track detected. Processing Video only...
    set "AUDIO_ARGS=-an"
)

rem Extract CreationTime
set "TMPCT=%TEMP%\ctime_%RANDOM%.txt"
powershell -NoP -C "$s=Get-Item '%SRC%'; if($s.CreationTime){$s.CreationTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')}else{'1970-01-01T00:00:00Z'}" > "%TMPCT%" 2>nul
set "CTIME="
if exist "%TMPCT%" set /p CTIME=<"%TMPCT%"
if exist "%TMPCT%" del /q "%TMPCT%" >nul 2>&1

echo [INFO] Encoding HEVC (NVENC)...

rem Try HEVC NVENC
ffmpeg -y -hide_banner -loglevel warning -hwaccel cuda -i "%SRC%" -c:v hevc_nvenc -cq %HEVC_CQ% -preset %PRESET% -pix_fmt yuv420p -tag:v hvc1 -vf "scale='if(gt(iw,ih),min(iw,%MAX_LONG%),-2)':'if(lt(iw,ih),min(ih,%MAX_LONG%),-2)'" %AUDIO_ARGS% -map_metadata 0 -metadata creation_time="%CTIME%" -movflags +faststart "%OUT%"

if errorlevel 1 (
    echo [ERROR] NVENC HEVC Failed. 
    echo         If drag-drop fails, check console output above.
    echo.
    if exist "%OUT%" del "%OUT%"
    goto :eof
)

rem Verification
if exist "%OUT%" (
    rem Check size > 100KB (Smallest valid video usually)
    for %%Z in ("%OUT%") do if %%~zZ LSS 100000 (
        echo [ERROR] Output too small/corrupt. Keeping Original.
        if exist "%OUT%" del "%OUT%"
        goto :eof
    )
    
    echo [OK] Conversion successful.
    
    rem Restore Timestamps
    powershell -NoP -C "$s=Get-Item '%SRC%'; $d=Get-Item '%OUT%'; $d.CreationTime=$s.CreationTime; $d.LastWriteTime=$s.LastWriteTime" >nul 2>&1
    
    rem DELETE ORIGINAL
    del "%SRC%"
    echo [INFO] Original deleted (Replaced by compressed version).
    
) else (
    echo [ERROR] Output file not created. Keeping Original.
)
goto :eof
