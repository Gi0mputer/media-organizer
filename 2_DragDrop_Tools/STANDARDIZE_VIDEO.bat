@echo off
REM ============================================================================
REM STANDARDIZE VIDEO - Drag & Drop Entry Point
REM ============================================================================
REM Standardizes ANY video to: 1080p 30fps H.264
REM Compatible with LosslessCut merge + Archive storage
REM ============================================================================

powershell -ExecutionPolicy Bypass -File "%~dp0STANDARDIZE_VIDEO_UNIVERSAL.ps1" %*
