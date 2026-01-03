@echo off
setlocal EnableExtensions

rem ============================================================================
rem Script Name: Downscale1920_HEVC.bat
rem Description: Downscales video files to 1920px (long edge) using HEVC (NVENC).
rem              Preserves metadata and file dates.
rem Dependencies: ffmpeg (with NVENC support)
rem ============================================================================

rem ===== CONFIG =====
set "SUFFIX= (small)"
set "MAX_LONG=1920"
set "CQ=21"        rem hevc_nvenc: 18=higher quality, 26=smaller size
set "PRESET=p5"
rem ===============

rem Check for ffmpeg
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] ffmpeg not found in PATH. Please install ffmpeg.
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

rem Avoid double compression if suffix exists
echo "%~n1" | findstr /c:"%SUFFIX%" >nul
if not errorlevel 1 (
  echo [SKIP] Already compressed: "%SRC%"
  echo.
  goto :eof
)

rem Avoid filename collisions
if exist "%OUT%" (
  set /a N=1
  :unique
  set "OUT=%~dpn1%SUFFIX% (%N%)%~x1"
  if exist "%OUT%" ( set /a N+=1 & goto :unique )
)

rem Prepare container flags for MP4/MOV (hvc1 + faststart)
set "TAGXV="
set "MP4FLAGS="
if /I "%EXT%"==".mp4" set "TAGXV=-tag:v hvc1" & set "MP4FLAGS=-movflags +faststart"
if /I "%EXT%"==".mov" set "TAGXV=-tag:v hvc1" & set "MP4FLAGS=-movflags +faststart"

rem Extract original CreationTime and convert to UTC ISO (for internal metadata)
set "TMPCT=%TEMP%\ctime_%RANDOM%.txt"
powershell -NoP -C "$s=Get-Item '%SRC%'; $s.CreationTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')" > "%TMPCT%" 2>nul
set "CTIME="
if exist "%TMPCT%" set /p CTIME=<"%TMPCT%"
if exist "%TMPCT%" del /q "%TMPCT%" >nul 2>&1
if "%CTIME%"=="" set "CTIME=1970-01-01T00:00:00Z"

echo ---------------------------------------------------------
echo Source   : %SRC%
echo Output   : %OUT%
echo Encoder  : hevc_nvenc CQ=%CQ% preset=%PRESET%
echo ---------------------------------------------------------

rem === Conversion ===
ffmpeg -y -hwaccel cuda -i "%SRC%" -c:v hevc_nvenc -cq %CQ% -preset %PRESET% -pix_fmt yuv420p %TAGXV% -vf "scale='if(gt(iw,ih),min(iw,%MAX_LONG%),-2)':'if(lt(iw,ih),min(ih,%MAX_LONG%),-2)'" -c:a copy -map_metadata 0 -metadata creation_time="%CTIME%" %MP4FLAGS% "%OUT%"
if errorlevel 1 (
  echo [ERROR] Conversion failed: %SRC%
  echo.
  goto :eof
)

rem Align NTFS dates (Creation/LastWrite) to source file
powershell -NoP -C "$s=Get-Item '%SRC%'; $d=Get-Item '%OUT%'; $d.CreationTime=$s.CreationTime; $d.LastWriteTime=$s.LastWriteTime" >nul 2>&1

echo [OK] Created: %OUT%
echo.
goto :eof
