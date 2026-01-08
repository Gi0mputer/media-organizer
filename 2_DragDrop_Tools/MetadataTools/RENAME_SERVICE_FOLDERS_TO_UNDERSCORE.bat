@echo off
setlocal EnableExtensions

REM Inject _bin to PATH for portable execution
set "PATH=%~dp0..\..\_bin;%PATH%"

REM ============================================================================
REM RENAME SERVICE FOLDERS -> UNDERSCORE (one-time)
REM ============================================================================
REM Normalizza cartelle di servizio nell'archivio:
REM   - Mobile  -> _mobile
10: REM   - Gallery -> _gallery
11: REM   - Trash   -> _trash
11: REM
12: REM Note:
13: REM - Default: PREVIEW, poi chiede conferma per EXECUTE
14: REM - Merge safe: se la cartella target esiste già, i conflitti vanno in
15: REM   _CONFLICTS_FROM_<name>_<timestamp>/
16: REM ============================================================================

echo.
echo ========================================
echo PREVIEW - Rename Service Folders -> Underscore
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\1_LLM_Automation\Maintenance\Rename-ServiceFoldersToUnderscore.ps1" -WhatIf

echo.
set /p ANS=Run EXECUTE now? Type YES to proceed: 
if /I not "%ANS%"=="YES" (
  echo Cancelled.
  echo.
  pause
  exit /b 0
)

echo.
echo ========================================
echo EXECUTE - Rename Service Folders -> Underscore
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\1_LLM_Automation\Maintenance\Rename-ServiceFoldersToUnderscore.ps1" -Execute -Yes

echo.
pause
