# Final Phone Cleanup - Scan remaining content and delete empty folders

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"

Write-Host "=== FINAL PHONE CLEANUP ===" -ForegroundColor Cyan

# 1. Show top-level folders and sizes
Write-Host "`n1. SCANNING TOP-LEVEL FOLDERS..." -ForegroundColor Yellow
Write-Host "Getting folder sizes (this may take a moment)...`n"

$topFolders = @(
    "/sdcard/DCIM"
    "/sdcard/Android"
    "/sdcard/Download"
    "/sdcard/Pictures"
    "/sdcard/Music"
    "/sdcard/Movies"
    "/sdcard/Documents"
    "/sdcard/Alarms"
    "/sdcard/Notifications"
    "/sdcard/Ringtones"
    "/sdcard/Podcasts"
)

$sizeReport = @()
foreach ($folder in $topFolders) {
    $size = & $adb shell "du -sh '$folder' 2>/dev/null"
    if ($size) {
        $sizeReport += $size
        Write-Host $size
    }
}

# 2. Find and list empty directories
Write-Host "`n2. FINDING EMPTY DIRECTORIES..." -ForegroundColor Yellow
$emptyDirs = & $adb shell "find /sdcard -type d -empty 2>/dev/null"

if ($emptyDirs) {
    $emptyCount = ($emptyDirs | Measure-Object).Count
    Write-Host "Found $emptyCount empty directories" -ForegroundColor Green
    
    Write-Host "`nFirst 20 empty directories:" -ForegroundColor Gray
    $emptyDirs | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}
else {
    Write-Host "No empty directories found" -ForegroundColor Green
}

# 3. Delete all empty directories
Write-Host "`n3. DELETING EMPTY DIRECTORIES..." -ForegroundColor Yellow

if ($emptyDirs) {
    Write-Host "Removing empty folders..." -NoNewline
    & $adb shell "find /sdcard -type d -empty -delete 2>/dev/null"
    Write-Host " Done!" -ForegroundColor Green
    
    # Verify
    $remainingEmpty = & $adb shell "find /sdcard -type d -empty 2>/dev/null | wc -l"
    $remainingCount = if ($remainingEmpty) { [int]$remainingEmpty.Trim() } else { 0 }
    
    if ($remainingCount -eq 0) {
        Write-Host "All empty directories removed" -ForegroundColor Green
    }
    else {
        Write-Host "$remainingCount empty directories remaining (may be protected)" -ForegroundColor Yellow
    }
}

# 4. Summary
Write-Host "`n=== CLEANUP SUMMARY ===" -ForegroundColor Cyan
Write-Host "Phone storage cleaned and optimized" -ForegroundColor Green
Write-Host "`nRemaining content is ready for manual review:" -ForegroundColor Yellow
Write-Host "  - DCIM/Camera (phone photos/videos)" -ForegroundColor Gray
Write-Host "  - Android/data (app data)" -ForegroundColor Gray
Write-Host "  - Download folder" -ForegroundColor Gray
