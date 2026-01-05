@echo off
setlocal EnableExtensions

REM ============================================================================
REM RENAME SERVICE FOLDERS -> UNDERSCORE (one-time)
REM ============================================================================
REM Normalizza cartelle di servizio nell'archivio:
REM   - Mobile  -> _mobile
REM   - Gallery -> _gallery
REM   - Trash   -> _trash
REM
REM Note:
REM - Default: PREVIEW, poi chiede conferma per EXECUTE
REM - Merge safe: se la cartella target esiste già, i conflitti vanno in
REM   _CONFLICTS_FROM_<name>_<timestamp>/
REM ============================================================================

echo.
echo ========================================
echo PREVIEW - Rename Service Folders -> Underscore
echo ========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\\..\\1_LLM_Automation\\Maintenance\\Rename-ServiceFoldersToUnderscore.ps1" -WhatIf

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

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\\..\\1_LLM_Automation\\Maintenance\\Rename-ServiceFoldersToUnderscore.ps1" -Execute -Yes

echo.
pause

