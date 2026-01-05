@echo off
setlocal EnableExtensions

REM ============================================================================
REM FIX DATE FROM REFERENCE - Drag & Drop Entry Point
REM ============================================================================
REM Uses a reference file (with correct metadata) to force all media files in
REM the target folder to that date (single-day events / controlled cases).
REM This is a wrapper for: 1_LLM_Automation\\Scripts\\Force-DateFromReference.ps1
REM
REM Usage: Drag & drop ONE reference media file onto this .bat
REM ============================================================================

if "%~1"=="" (
  echo Drag and drop ONE reference media FILE onto this script.
  echo It will apply the reference date to the whole folder.
  echo.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\\..\\1_LLM_Automation\\Scripts\\Force-DateFromReference.ps1" "%~1"

