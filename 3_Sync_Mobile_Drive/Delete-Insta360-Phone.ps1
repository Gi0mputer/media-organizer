# Delete all Insta360 files from phone

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"

Write-Host "=== DELETING INSTA360 FILES FROM PHONE ===" -ForegroundColor Cyan

# Delete entire galleryOriginal folder (contains all the videos)
Write-Host "`nDeleting Insta360OneR/galleryOriginal folder..." -NoNewline

& $adb shell "rm -rf /sdcard/Android/data/com.arashivision.insta360akiko/files/Insta360OneR/galleryOriginal" 2>&1 | Out-Null

Write-Host " Done!" -ForegroundColor Green

# Verify deletion
$remaining = & $adb shell "find /sdcard/Android/data/com.arashivision.insta360akiko/files/Insta360OneR/galleryOriginal -type f 2>/dev/null | wc -l"

if ($remaining -match '^\s*0\s*$' -or [string]::IsNullOrWhiteSpace($remaining)) {
    Write-Host "`nDeletion verified - folder empty or removed" -ForegroundColor Green
}
else {
    Write-Host "`nWarning: $remaining files still present" -ForegroundColor Yellow
}

Write-Host "`nInsta360 cleanup complete!" -ForegroundColor Cyan
