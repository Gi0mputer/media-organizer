@echo off
setlocal EnableExtensions

rem ============================================================================
rem Script Name: Dates_Diagnostics_PLUS_Console.bat
rem Description: Analyzes file dates (Exif vs FileSystem) in a folder.
rem              Uses ExifTool if available.
rem Usage: Drag and drop a folder onto this script, or run without arguments.
rem ============================================================================

set "ROOT=%~1"
if "%ROOT%"=="" set "ROOT=%cd%"

echo ==========================================
echo  Dates Diagnostics (console)
echo  Script : %~f0
echo  Root   : "%ROOT%"
echo ==========================================
echo.

if not exist "%ROOT%" (
  echo [ERROR] Folder not found: "%ROOT%"
  echo.
  pause
  goto :eof
)

rem --- RESOLVE EXIFTOOL ---
set "EXIFTOOL="

rem 1) Next to the .bat
if exist "%~dp0exiftool.exe" set "EXIFTOOL=%~dp0exiftool.exe"

rem 2) System PATH
if not defined EXIFTOOL (
  for %%I in (exiftool.exe) do (
    if exist "%%~$PATH:I" set "EXIFTOOL=%%~$PATH:I"
  )
)

if defined EXIFTOOL (
  echo ExifTool: "%EXIFTOOL%"
) else (
  echo ExifTool: NOT found (diagnostics limited to filesystem timestamps only)
)
echo.

rem --- Run PowerShell Script ---
set "PS1=%~dp0Dates_Diagnostics.ps1"
if not exist "%PS1%" (
    echo [ERROR] Helper script not found: "%PS1%"
    pause
    goto :eof
)

echo Starting PowerShell diagnostics...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Root "%ROOT%" -ExifToolPath "%EXIFTOOL%"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo [ERROR] Diagnostics failed. Code: %RC%
) else (
  echo [OK] Diagnostics completed.
)
echo.
pause
