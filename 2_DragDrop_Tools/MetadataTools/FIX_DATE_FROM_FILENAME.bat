@echo off
setlocal EnableExtensions

REM ============================================================================
REM FIX DATE FROM FILENAME - Drag & Drop Entry Point
REM ============================================================================
REM Use case: Windows/Microsoft Photos trim/export can reset dates to "today",
REM causing wrong ordering in gallery timelines. This tool parses YYYYMMDD from
REM filename and rewrites metadata + filesystem timestamps.
REM
REM Usage: Drag & drop file(s) or folder(s) onto this .bat
REM ============================================================================

if "%~1"=="" (
  echo Drag and drop one or more FILES or FOLDERS onto this script.
  echo.
  echo Notes:
  echo - Default safety: only fixes files whose filesystem date is recent (today/yesterday).
  echo - To force fixing all matched files, run the .ps1 with -Force.
  echo.
  pause
  exit /b 1
)

echo.
echo ========================================
echo PREVIEW - Fix Date From Filename
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-DateFromFilename.ps1" -WhatIf %*

echo.
set /p ANS=Run EXECUTE now? Type YES to proceed: 
if /I not "%ANS%"=="YES" (
  echo Cancelled.
  pause
  exit /b 0
)

echo.
echo ========================================
echo EXECUTE - Fix Date From Filename
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-DateFromFilename.ps1" %*

echo.
pause
