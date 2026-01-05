@echo off
setlocal
cd /d "%~dp0"

echo ========================================================
echo  SMART DUPLICATE FINDER
echo  - Finds EXACT duplicates (Hash)
echo  - Finds WHATSAPP duplicates (Duration + Pattern)
echo ========================================================
echo.

set "TARGET=D:\2023"
if not "%~1"=="" set "TARGET=%~1"

echo Target Folder: %TARGET%
echo.
echo Choose Mode:
echo [1] DRY RUN (Analyze only, create report)
echo [2] DELETE MODE (Move duplicates to Recycle Bin)
echo.
set /p "CHOICE=Enter choice (1 or 2): "

if "%CHOICE%"=="2" (
    echo.
    echo WARNING: YOU ARE ABOUT TO DELETE FILES.
    echo Duplicates will be moved to the Recycle Bin.
    echo Are you sure?
    pause
    powershell -NoProfile -ExecutionPolicy Bypass -File "SmartDuplicateFinder.ps1" -SourcePath "%TARGET%" -Delete
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "SmartDuplicateFinder.ps1" -SourcePath "%TARGET%"
)

echo.
echo Done. Check the generated DUPLICATE_REPORT_*.txt in 1_LLM_Automation\Analysis\
pause
