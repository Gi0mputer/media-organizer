# Phone-PC File Comparison Script
# Compares files on phone (SSD/DCIM) with PC (E:\) to identify duplicates

param(
    [switch]$Detailed
)

$adb = "$PSScriptRoot\Tools\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { Write-Error "ADB not found"; exit 1 }

Write-Host "=== PHONE-PC FILE COMPARISON ===" -ForegroundColor Cyan
Write-Host "Scanning files..." -ForegroundColor Yellow

# 1. Get Phone Files (SSD + DCIM/SSD)
Write-Host "`nScanning Phone..." -NoNewline
$phoneFiles = @{}
$phoneRaw = & $adb shell "find /sdcard/SSD /sdcard/DCIM/SSD -type f -printf '%p|%s\n' 2>/dev/null"

foreach ($line in $phoneRaw) {
    if ($line -match '^(.+)\|(\d+)$') {
        $path = $matches[1]
        $size = [long]$matches[2]
        $name = Split-Path $path -Leaf
        
        # Skip system files
        if ($name -match '^\.') { continue }
        
        $key = "$name|$size"
        if (-not $phoneFiles.ContainsKey($key)) {
            $phoneFiles[$key] = @()
        }
        $phoneFiles[$key] += $path
    }
}
Write-Host " Found $($phoneFiles.Count) unique file signatures" -ForegroundColor Green

# 2. Get PC Files (E:\ only, excluding _trash)
Write-Host "Scanning PC (E:\)..." -NoNewline
$pcFiles = @{}
$pcItems = Get-ChildItem -Path "E:\" -Recurse -File -ErrorAction SilentlyContinue | 
Where-Object { $_.FullName -notmatch '\\_trash\\' -and $_.FullName -notmatch '\\_sys\\' }

foreach ($f in $pcItems) {
    $key = "$($f.Name)|$($f.Length)"
    if (-not $pcFiles.ContainsKey($key)) {
        $pcFiles[$key] = @()
    }
    $pcFiles[$key] += $f.FullName
}
Write-Host " Found $($pcFiles.Count) unique file signatures" -ForegroundColor Green

# 3. Analysis
Write-Host "`n=== ANALYSIS ===" -ForegroundColor Cyan

$identical = @()      # Files on phone that exist on PC (safe to delete)
$uniquePhone = @()    # Files only on phone (need review)

foreach ($phoneKey in $phoneFiles.Keys) {
    $phonePaths = $phoneFiles[$phoneKey]
    
    if ($pcFiles.ContainsKey($phoneKey)) {
        # File exists on PC
        $pcPaths = $pcFiles[$phoneKey]
        
        foreach ($phonePath in $phonePaths) {
            $identical += [pscustomobject]@{
                PhonePath = $phonePath
                PCPath    = $pcPaths[0]
                Size      = ($phoneKey -split '\|')[1]
                Name      = ($phoneKey -split '\|')[0]
            }
        }
    }
    else {
        # File NOT on PC
        foreach ($phonePath in $phonePaths) {
            $uniquePhone += [pscustomobject]@{
                PhonePath = $phonePath
                Size      = ($phoneKey -split '\|')[1]
                Name      = ($phoneKey -split '\|')[0]
            }
        }
    }
}

# 4. Report
Write-Host "`nRESULTS:" -ForegroundColor Yellow
Write-Host "  Identical (safe to delete from phone): $($identical.Count)" -ForegroundColor Green
Write-Host "  Unique on phone (need review): $($uniquePhone.Count)" -ForegroundColor Yellow

# Calculate space savings
$spaceToFree = ($identical | Measure-Object -Property Size -Sum).Sum
$spaceGB = [math]::Round($spaceToFree / 1GB, 2)
Write-Host "`nSpace to free: $spaceGB GB" -ForegroundColor Cyan

# 5. Export Results
$reportPath = "$PSScriptRoot\phone_comparison_report.json"
$report = @{
    Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Identical   = $identical
    UniquePhone = $uniquePhone
    Summary     = @{
        IdenticalCount = $identical.Count
        UniqueCount    = $uniquePhone.Count
        SpaceToFreeGB  = $spaceGB
    }
}

$report | ConvertTo-Json -Depth 5 | Set-Content $reportPath
Write-Host "`nReport saved: $reportPath" -ForegroundColor Gray

# 6. Show samples
if ($Detailed) {
    Write-Host "`n=== SAMPLE IDENTICAL FILES (First 20) ===" -ForegroundColor Cyan
    $identical | Select-Object -First 20 | Format-Table -AutoSize PhonePath, Name, Size
    
    Write-Host "`n=== SAMPLE UNIQUE FILES (First 20) ===" -ForegroundColor Yellow
    $uniquePhone | Select-Object -First 20 | Format-Table -AutoSize PhonePath, Name, Size
}

Write-Host "`nDone! Review the report to decide what to delete." -ForegroundColor Green
