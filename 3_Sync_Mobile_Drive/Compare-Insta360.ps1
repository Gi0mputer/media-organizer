# Insta360 Files Comparison Script
# Compares Insta360 files on phone with PC (E:\Insta360x4, E:\Insta360x5)

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"

Write-Host "=== INSTA360 FILES COMPARISON ===" -ForegroundColor Cyan

# 1. Get Phone Insta360 Files
Write-Host "`nScanning Phone Insta360 folder..." -NoNewline
$phoneFiles = @{}
$phoneRaw = & $adb shell "find /sdcard/Android/data/com.arashivision.insta360akiko/files/Insta360OneR/galleryOriginal -type f \( -name '*.insv' -o -name '*.insp' -o -name '*.dng' \) -printf '%p|%s\n' 2>/dev/null"

foreach ($line in $phoneRaw) {
    if ($line -match '^(.+)\|(\d+)$') {
        $path = $matches[1]
        $size = [long]$matches[2]
        $name = Split-Path $path -Leaf
        
        $key = "$name|$size"
        if (-not $phoneFiles.ContainsKey($key)) {
            $phoneFiles[$key] = @()
        }
        $phoneFiles[$key] += $path
    }
}
Write-Host " Found $($phoneFiles.Count) unique files on phone" -ForegroundColor Green

# 2. Get PC Files (E:\Insta360x4 and E:\Insta360x5)
Write-Host "Scanning PC (E:\Insta360*)..." -NoNewline
$pcFiles = @{}

$pcPaths = @()
if (Test-Path "E:\Insta360x4") { $pcPaths += "E:\Insta360x4" }
if (Test-Path "E:\Insta360x5") { $pcPaths += "E:\Insta360x5" }

foreach ($pcPath in $pcPaths) {
    $items = Get-ChildItem -Path $pcPath -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $items) {
        $key = "$($f.Name)|$($f.Length)"
        if (-not $pcFiles.ContainsKey($key)) {
            $pcFiles[$key] = @()
        }
        $pcFiles[$key] += $f.FullName
    }
}
Write-Host " Found $($pcFiles.Count) unique files on PC" -ForegroundColor Green

# 3. Analysis
Write-Host "`n=== ANALYSIS ===" -ForegroundColor Cyan

$alreadySaved = @()
$needToSave = @()

foreach ($phoneKey in $phoneFiles.Keys) {
    $phonePaths = $phoneFiles[$phoneKey]
    
    if ($pcFiles.ContainsKey($phoneKey)) {
        # File exists on PC
        $pcPaths = $pcFiles[$phoneKey]
        foreach ($phonePath in $phonePaths) {
            $alreadySaved += [pscustomobject]@{
                PhonePath = $phonePath
                PCPath    = $pcPaths[0]
                Size      = ($phoneKey -split '\|')[1]
                Name      = ($phoneKey -split '\|')[0]
            }
        }
    }
    else {
        # File NOT on PC - need to save
        foreach ($phonePath in $phonePaths) {
            $needToSave += [pscustomobject]@{
                PhonePath = $phonePath
                Size      = ($phoneKey -split '\|')[1]
                Name      = ($phoneKey -split '\|')[0]
            }
        }
    }
}

# 4. Report
Write-Host "`nRESULTS:" -ForegroundColor Yellow
Write-Host "  Already saved on PC (can delete): $($alreadySaved.Count)" -ForegroundColor Green
Write-Host "  Need to save: $($needToSave.Count)" -ForegroundColor Red

$spaceAlreadySaved = ($alreadySaved | Measure-Object -Property Size -Sum).Sum / 1GB
$spaceToSave = ($needToSave | Measure-Object -Property Size -Sum).Sum / 1GB

Write-Host "`nSpace breakdown:" -ForegroundColor Cyan
Write-Host "  Already saved: $([math]::Round($spaceAlreadySaved, 2)) GB (can free)" -ForegroundColor Green
Write-Host "  Need to save: $([math]::Round($spaceToSave, 2)) GB" -ForegroundColor Yellow

# 5. Export
$report = @{
    Timestamp    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    AlreadySaved = $alreadySaved
    NeedToSave   = $needToSave
    Summary      = @{
        AlreadySavedCount   = $alreadySaved.Count
        NeedToSaveCount     = $needToSave.Count
        SpaceAlreadySavedGB = [math]::Round($spaceAlreadySaved, 2)
        SpaceToSaveGB       = [math]::Round($spaceToSave, 2)
    }
}

$report | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot\insta360_report.json"
Write-Host "`nReport saved: insta360_report.json" -ForegroundColor Gray

# 6. Show samples
Write-Host "`n=== FILES ALREADY ON PC (First 10) ===" -ForegroundColor Green
$alreadySaved | Select-Object -First 10 | Format-Table -AutoSize Name, @{Label = "Size(MB)"; Expression = { [math]::Round($_.Size / 1MB, 2) } }

Write-Host "`n=== FILES TO SAVE (First 10) ===" -ForegroundColor Yellow
$needToSave | Select-Object -First 10 | Format-Table -AutoSize Name, @{Label = "Size(MB)"; Expression = { [math]::Round($_.Size / 1MB, 2) } }
