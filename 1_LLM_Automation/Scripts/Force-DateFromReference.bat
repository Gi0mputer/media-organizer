@echo off
setlocal EnableExtensions

rem ============================================================================
rem Wrapper: Force-DateFromReference.bat
rem Description: Drag & drop a REFERENCE FILE to run Force-DateFromReference.ps1
rem Safety: Runs PREVIEW first, then asks if you want to execute.
rem ============================================================================

set "REF=%~1"
if "%REF%"=="" (
  echo Drag and drop a REFERENCE FILE onto this script.
  echo.
  pause
  goto :eof
)

if not exist "%REF%" (
  echo [ERROR] File not found: "%REF%"
  echo.
  pause
  goto :eof
)

set "PS1=%~dp0Force-DateFromReference.ps1"
if not exist "%PS1%" (
  echo [ERROR] Script not found: "%PS1%"
  echo.
  pause
  goto :eof
)

echo ==========================================
echo  Force Date From Reference (wrapper)
echo  Reference : "%REF%"
echo ==========================================
echo.

echo [STEP 1/2] PREVIEW (-WhatIf)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ReferencePath "%REF%" -WhatIf
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -ReferencePath "%REF%"
echo.
pause

