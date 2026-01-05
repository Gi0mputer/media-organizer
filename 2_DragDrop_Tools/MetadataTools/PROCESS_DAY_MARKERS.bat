@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================================
REM PROCESS DAY MARKERS - Drag & Drop Entry Point
REM ============================================================================
REM Handles helper folders used during manual sorting:
REM - 1day\ (legacy alias: sameday\) + optional suffix: 1day_2\, 1day_3\ ...
REM - Nday\  (e.g. 4day\) + optional suffix: 4day_2\, 4day_3\ ...
REM
REM Workflow:
REM 1) Preview
REM 2) Optional execute (asks YES)
REM ============================================================================

if "%~1"=="" (
  echo Drag and drop one or more FOLDERS (or a disk root) onto this script.
  echo It will scan recursively for: 1day (or sameday), Nday
  echo.
  pause
  exit /b 1
)

set "PS1=%~dp0..\..\1_LLM_Automation\Maintenance\Process-DayMarkerFolders.ps1"

echo.
echo ========================================
echo PREVIEW - Process Day Marker Folders
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*

echo.
set /p ANS=Run EXECUTE now? Type YES to proceed: 
if /I not "%ANS%"=="YES" (
  echo Cancelled.
  pause
  exit /b 0
)

echo.
echo ========================================
echo EXECUTE - Process Day Marker Folders
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %* -Execute -Yes

echo.
pause
