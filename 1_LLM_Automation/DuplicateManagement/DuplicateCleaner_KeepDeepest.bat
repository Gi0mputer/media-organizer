@echo off
setlocal EnableExtensions

rem ============================================================================
rem Script Name: DuplicateCleaner_KeepDeepest.bat
rem Description: Finds duplicates by NAME + SIZE.
rem              Keeps the copy in the deepest folder.
rem              If depth is equal, keeps the oldest file.
rem Usage:
rem   Drag and drop a folder onto this .bat (DRY-RUN)
rem   Or: "DuplicateCleaner_KeepDeepest.bat" "Folder" [/go] [/list]
rem   /go   = Delete to Recycle Bin (with confirmation)
rem   /list = List all examples in DRY-RUN (not just first 60)
rem ============================================================================

setlocal DisableDelayedExpansion

rem --- Root ---
set "ROOT=%~1"
if "%ROOT%"=="" set "ROOT=%cd%"

rem --- Optional flags ---
set "DELETE_FLAG="
set "LIST_FLAG="

for %%A in (%*) do (
  if /I "%%~A"=="/go"   set "DELETE_FLAG=-Delete"
  if /I "%%~A"=="/list" set "LIST_FLAG=-ListAll"
)

if not exist "%ROOT%" (
  echo [ERROR] Folder not found: "%ROOT%"
  echo.
  goto :END
)

if defined DELETE_FLAG (set "MODE=DELETION") else (set "MODE=DRY-RUN")

echo =============================================
echo  Duplicate Cleaner (Name + Size)
echo  Root: "%ROOT%"
echo  Mode: %MODE%
echo =============================================
echo.

rem --- Run PowerShell Script ---
set "PS1=%~dp0DuplicateCleaner.ps1"
if not exist "%PS1%" (
    echo [ERROR] Helper script not found: "%PS1%"
    pause
    goto :END
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -Root "%ROOT%" %DELETE_FLAG% %LIST_FLAG%
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo [ERROR] Finished with code: %RC%
) else (
  if defined DELETE_FLAG (
    echo [OK] Deletion completed.
  ) else (
    echo [OK] Preview completed. To delete use: "%~nx0" "folder" /go
  )
)
echo.

:END
pause
