@echo off
echo === RUN: Flatten Nested _pc Folders ===
echo Collassa le cartelle _pc annidate spostando il contenuto nella _pc genitore.
echo Es: Evento\_pc\Sub\_pc\file  ->  Evento\_pc\Sub\file
echo.
set /p CONFIRM=Digita SI per continuare:
if /i not "%CONFIRM%"=="SI" ( echo Annullato. & pause & exit /b )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Flatten-NestedPc.ps1" -Execute
echo.
pause
