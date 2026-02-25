# Clean app cache from phone and duplicates from PC

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"

Write-Host "=== FINAL CLEANUP: PHONE CACHE + PC DUPLICATES ===" -ForegroundColor Cyan

# PART 1: Phone cache cleanup
Write-Host "`n1. CLEANING PHONE APP CACHE..." -ForegroundColor Yellow

$cacheFolders = @(
    "/sdcard/Android/data/com.arashivision.insta360akiko/cache"
    "/sdcard/Android/data/dji.go.v5/cache"
    "/sdcard/Android/data/org.telegram.messenger/cache"
)

$totalPhoneFreed = 0

foreach ($folder in $cacheFolders) {
    $appName = ($folder -split '/')[4]
    
    Write-Host "`nCleaning $appName..." -NoNewline
    
    # Get size before
    $sizeBefore = & $adb shell "du -s '$folder' 2>/dev/null"
    if ($sizeBefore -match '^\s*(\d+)') {
        $sizeKB = [long]$matches[1]
        $totalPhoneFreed += $sizeKB
        
        Write-Host " $([math]::Round($sizeKB/1024, 2)) MB" -ForegroundColor Yellow
        
        # Delete cache
        & $adb shell "rm -rf '$folder'/*" 2>&1 | Out-Null
        Write-Host "  Deleted!" -ForegroundColor Green
    }
    else {
        Write-Host " Not found or empty" -ForegroundColor Gray
    }
}

Write-Host "`nPhone cache cleanup:" -ForegroundColor Cyan
Write-Host "  Space freed: $([math]::Round($totalPhoneFreed/1024/1024, 2)) GB" -ForegroundColor Green

# PART 2: PC duplicates cleanup
Write-Host "`n2. CLEANING PC DUPLICATES (Scianco folder)..." -ForegroundColor Yellow

$sciancoPath = "E:\_drone\FPV\Scianco\Scianco"

if (Test-Path $sciancoPath) {
    Write-Host "Analyzing $sciancoPath..." -NoNewline
    
    $files = Get-ChildItem -Path $sciancoPath -File -ErrorAction SilentlyContinue
    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
    
    Write-Host " $($files.Count) files ($([math]::Round($totalSize/1GB, 2)) GB)" -ForegroundColor Yellow
    
    Write-Host "Deleting duplicates..." -NoNewline
    
    try {
        Remove-Item "$sciancoPath\*" -Force -ErrorAction Stop
        Write-Host " Done!" -ForegroundColor Green
        
        Write-Host "`nPC duplicates cleanup:" -ForegroundColor Cyan
        Write-Host "  Files deleted: $($files.Count)" -ForegroundColor Green
        Write-Host "  Space freed: $([math]::Round($totalSize/1GB, 2)) GB" -ForegroundColor Green
    }
    catch {
        Write-Host " FAILED" -ForegroundColor Red
    }
}
else {
    Write-Host "Scianco folder not found, skipping" -ForegroundColor Gray
}

# PART 3: Final phone status
Write-Host "`n3. FINAL PHONE STATUS..." -ForegroundColor Yellow

$remainingSize = & $adb shell "du -sh /sdcard 2>/dev/null"
Write-Host "Total /sdcard size: $remainingSize" -ForegroundColor Cyan

Write-Host "`n=== CLEANUP COMPLETE ===" -ForegroundColor Green
Write-Host "Phone is now clean and ready for backup/factory reset" -ForegroundColor Green
