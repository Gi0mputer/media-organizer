@echo off
REM ============================================================================
REM VIDEO REPAIR - Drag & Drop Entry Point
REM ============================================================================

REM Inject _bin to PATH for portable execution
set "PATH=%~dp0..\_bin;%PATH%"

REM Automatically fixes:
REM - Corrupted metadata (FPS, duration)
REM - Broken merges (LosslessCut glitches)
REM - Container issues
REM Output: filename_FIXED.mp4
REM ============================================================================

powershell -ExecutionPolicy Bypass -File "%~dp0VideoRepair\REPAIR_VIDEO.ps1" %*
