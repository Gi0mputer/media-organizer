@echo off
setlocal EnableExtensions

rem ============================================================================
rem Wrapper: Force-DateToMax.bat
rem Description: Drag & drop a FOLDER to run Force-DateToMax.ps1
rem Safety: Runs PREVIEW first, then asks if you want to execute.
rem ============================================================================

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%cd%"

echo ==========================================
echo  Force Date To MAX (wrapper)
echo  Folder : "%TARGET%"
echo ==========================================
echo.

if not exist "%TARGET%" (
  echo [ERROR] Folder not found: "%TARGET%"
  echo.
  pause
  goto :eof
)

set "PS1=%~dp0Force-DateToMax.ps1"
if not exist "%PS1%" (
  echo [ERROR] Script not found: "%PS1%"
  echo.
  pause
  goto :eof
)

echo [STEP 1/2] PREVIEW (-WhatIf)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -FolderPath "%TARGET%" -WhatIf
echo.

set /p "ANS=Run EXECUTE now? Type YES to proceed: "
if /I not "%ANS%"=="YES" (
  echo Cancelled.
  echo.
  pause
  goto :eof
)

echo.
echo [STEP 2/2] EXECUTE
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -FolderPath "%TARGET%"
echo.
pause

