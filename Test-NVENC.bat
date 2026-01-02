@echo off
echo Testing NVENC availability...
echo.

ffmpeg -v error -f lavfi -i color=black:s=1920x1080 -vframes 60 -c:v hevc_nvenc -f null -
if errorlevel 1 (
    echo [FAIL] HEVC NVENC is NOT working.
) else (
    echo [PASS] HEVC NVENC is WORKING correctly!
)

echo.
echo Testing H.264 NVENC...
ffmpeg -v error -f lavfi -i color=black:s=1920x1080 -vframes 60 -c:v h264_nvenc -f null -
if errorlevel 1 (
    echo [FAIL] H.264 NVENC is NOT working.
) else (
    echo [PASS] H.264 NVENC is WORKING correctly!
)

echo.
pause
