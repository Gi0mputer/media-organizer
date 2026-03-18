@echo off
echo === PREVIEW: Flatten Nested _pc Folders ===
echo Mostra le cartelle _pc annidate che verrebbero collassate.
echo Nessuna modifica reale.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Flatten-NestedPc.ps1"
echo.
pause
