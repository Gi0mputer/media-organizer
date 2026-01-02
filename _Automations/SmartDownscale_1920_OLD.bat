@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ============================================================================
rem Script Name: SmartDownscale_1920.bat
rem Description: Downscales video to 1920px (long edge).
rem              - Skips if already smaller or equal.
rem              - Tries HEVC NVENC, falls back to H.264 NVENC.
rem              - Preserves metadata and file dates.
rem Usage: Drag and drop files onto this .bat
rem Dependencies: ffmpeg, ffprobe
rem ============================================================================

rem ===== CONFIG =====
set "SUFFIX= (small)"
set "MAX_LONG=1920"
set "HEVC_CQ=21"
set "H264_CQ=22"
set "PRESET=p5"
rem ===============

rem Check dependencies
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg not found in PATH.
    pause
    exit /b
)
where ffprobe >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffprobe not found in PATH.
    pause
    exit /b
)

if "%~1"=="" (
    echo Drag and drop one or more video files onto this .bat file.
    pause
    exit /b
)

for %%F in (%*) do call :PROCESS "%%~fF"

echo.
echo Finished.
pause
exit /b


:PROCESS
set "SRC=%~1"
set "OUT=%~dpn1%SUFFIX%%~x1"
set "EXT=%~x1"

rem Check if already compressed
echo "%~n1" | findstr /c:"%SUFFIX%" >nul
if not errorlevel 1 (
    echo [SKIP] Already compressed: "%SRC%"
    echo.
    goto :eof
)

rem Check dimensions with ffprobe
set "W=" & set "H=" & set "LONG="
for /f "usebackq tokens=1,2 delims=x" %%a in (`
  ffprobe -v error -select_streams v^:0 -show_entries stream^=width,height -of csv^=p^=0^:s^=x "%SRC%"
`) do (
  set "W=%%a"
  set "H=%%b"
)

if defined W (
  if !H! GTR !W! (set /a LONG=!H!) else (set /a LONG=!W!)
  if !LONG! LEQ %MAX_LONG% (
    echo [SKIP] Already ^<= %MAX_LONG% px (long edge !LONG!): "%SRC%"
    echo.
    goto :eof
  )
) else (
  echo [INFO] ffprobe could not determine dimensions. Proceeding anyway.
)

rem Avoid filename collisions
if exist "%OUT%" (
  set /a N=1
  :unique
  set "OUT=%~dpn1%SUFFIX% (!N!)%~x1"
  if exist "%OUT%" ( set /a N+=1 & goto :unique )
)

rem Container flags
set "TAGXV="
set "MP4FLAGS="
if /I "%EXT%"==".mp4" set "TAGXV=-tag:v hvc1" & set "MP4FLAGS=-movflags +faststart"
if /I "%EXT%"==".mov" set "TAGXV=-tag:v hvc1" & set "MP4FLAGS=-movflags +faststart"

rem Extract CreationTime
set "TMPCT=%TEMP%\ctime_%RANDOM%.txt"
powershell -NoP -C "$s=Get-Item '%SRC%'; $s.CreationTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')" > "%TMPCT%" 2>nul
set "CTIME="
if exist "%TMPCT%" set /p CTIME=<"%TMPCT%"
if exist "%TMPCT%" del /q "%TMPCT%" >nul 2>&1
if "%CTIME%"=="" set "CTIME=1970-01-01T00:00:00Z"

echo ---------------------------------------------------------
echo Source   : %SRC%
echo Output   : %OUT%
echo Encoder  : hevc_nvenc CQ=%HEVC_CQ% (fallback h264_nvenc CQ=%H264_CQ%)
echo ---------------------------------------------------------

rem Try HEVC NVENC
ffmpeg -y -v error -hwaccel cuda -i "%SRC%" -c:v hevc_nvenc -cq %HEVC_CQ% -preset %PRESET% -pix_fmt yuv420p %TAGXV% -vf "scale='if(gt(iw,ih),min(iw,%MAX_LONG%),-2)':'if(lt(iw,ih),min(ih,%MAX_LONG%),-2)'" -c:a copy -map_metadata 0 -metadata creation_time="%CTIME%" %MP4FLAGS% "%OUT%"

if errorlevel 1 (
    echo [INFO] HEVC NVENC failed, trying H.264 NVENC...
    if exist "%OUT%" del "%OUT%"
    ffmpeg -y -v error -hwaccel cuda -i "%SRC%" -c:v h264_nvenc -cq %H264_CQ% -preset %PRESET% -pix_fmt yuv420p -vf "scale='if(gt(iw,ih),min(iw,%MAX_LONG%),-2)':'if(lt(iw,ih),min(ih,%MAX_LONG%),-2)'" -c:a copy -map_metadata 0 -metadata creation_time="%CTIME%" %MP4FLAGS% "%OUT%"
)

rem Verify output
set "OKFLAG="
if exist "%OUT%" for %%Z in ("%OUT%") do if %%~zZ GTR 0 set "OKFLAG=1"

if not defined OKFLAG (
    echo [ERROR] Conversion failed: %SRC%
    if exist "%OUT%" del "%OUT%"
    echo.
    goto :eof
)

rem Align dates
powershell -NoP -C "$s=Get-Item '%SRC%'; $d=Get-Item '%OUT%'; $d.CreationTime=$s.CreationTime; $d.LastWriteTime=$s.LastWriteTime" >nul 2>&1

echo [OK] Created: %OUT%
echo.
goto :eof
