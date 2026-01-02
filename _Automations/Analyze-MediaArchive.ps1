param(
    [string]$RecentPath = "D:\",
    [string]$OldPath = "E:\",
    [string]$OutputPath = "$env:USERPROFILE\Desktop\media_analysis.txt"
)

Write-Host "=== MEDIA ARCHIVE ANALYSIS ===" -ForegroundColor Cyan
Write-Host "Recent SSD: $RecentPath"
Write-Host "Old SSD: $OldPath"
Write-Host ""

$report = @()
$report += "=" * 80
$report += "MEDIA ARCHIVE ANALYSIS - $(Get-Date)"
$report += "=" * 80
$report += ""

# Video extensions
$videoExts = @('.mp4', '.mov', '.avi', '.mkv', '.insv', '.m4v', '.wmv', '.flv', '.webm', '.mpg', '.mpeg')
$photoExts = @('.jpg', '.jpeg', '.png', '.heic', '.raw', '.cr2', '.nef', '.dng', '.arw', '.gif', '.bmp', '.tiff')

function Analyze-Drive {
    param($Path, $Name)
    
    Write-Host "`n[ANALYZING: $Name]" -ForegroundColor Yellow
    $report += "`n" + "=" * 80
    $report += "DRIVE: $Name ($Path)"
    $report += "=" * 80
    
    # Get all files
    Write-Host "  Scanning files..." -ForegroundColor Gray
    $allFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
    
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum / 1GB
    $totalCount = $allFiles.Count
    
    $report += "`nOVERALL STATISTICS"
    $report += "-" * 40
    $report += "Total Files: $totalCount"
    $report += "Total Size: $([math]::Round($totalSize, 2)) GB"
    
    # Video analysis
    Write-Host "  Analyzing videos..." -ForegroundColor Gray
    $videos = $allFiles | Where-Object { $videoExts -contains $_.Extension.ToLower() }
    $videosByExt = $videos | Group-Object Extension | Sort-Object Count -Descending
    
    $report += "`nVIDEO FILES"
    $report += "-" * 40
    $report += "Total Videos: $($videos.Count)"
    $report += "Total Size: $([math]::Round(($videos | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
    $report += "`nBy Extension:"
    foreach ($ext in $videosByExt) {
        $size = [math]::Round(($ext.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        $report += "  $($ext.Name): $($ext.Count) files, $size GB"
    }
    
    # .insv analysis (360 files - outliers)
    $insvFiles = $videos | Where-Object { $_.Extension.ToLower() -eq '.insv' }
    if ($insvFiles.Count -gt 0) {
        $report += "`n360 FILES (.insv) - OUTLIERS"
        $report += "-" * 40
        $report += "Count: $($insvFiles.Count)"
        $report += "Size: $([math]::Round(($insvFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
        $report += "Location: $((Get-ChildItem -Path $Path -Recurse -Directory | Where-Object { ($_ | Get-ChildItem -Filter "*.insv" -ErrorAction SilentlyContinue).Count -gt 0 } | Select-Object -First 5 -ExpandProperty FullName) -join ', ')"
    }
    
    # Photo analysis
    Write-Host "  Analyzing photos..." -ForegroundColor Gray
    $photos = $allFiles | Where-Object { $photoExts -contains $_.Extension.ToLower() }
    $photosByExt = $photos | Group-Object Extension | Sort-Object Count -Descending
    
    $report += "`nPHOTO FILES"
    $report += "-" * 40
    $report += "Total Photos: $($photos.Count)"
    $report += "Total Size: $([math]::Round(($photos | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
    $report += "`nBy Extension:"
    foreach ($ext in $photosByExt | Select-Object -First 10) {
        $size = [math]::Round(($ext.Group | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        $report += "  $($ext.Name): $($ext.Count) files, $size GB"
    }
    
    # Top 20 largest files
    Write-Host "  Finding largest files..." -ForegroundColor Gray
    $largest = $allFiles | Sort-Object Length -Descending | Select-Object -First 20
    
    $report += "`nTOP 20 LARGEST FILES"
    $report += "-" * 40
    foreach ($file in $largest) {
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $relPath = $file.FullName.Replace($Path, "")
        $report += "  $sizeMB MB - $relPath"
    }
    
    # Folder analysis by year
    Write-Host "  Analyzing folders by year..." -ForegroundColor Gray
    $yearFolders = Get-ChildItem -Path $Path -Directory -Depth 0 | 
    Where-Object { $_.Name -match '^\d{4}' -or $_.Name -match '^\d{4}.*' } |
    ForEach-Object {
        $folderFiles = Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name   = $_.Name
            Files  = $folderFiles.Count
            SizeGB = [math]::Round(($folderFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
            Videos = ($folderFiles | Where-Object { $videoExts -contains $_.Extension.ToLower() }).Count
            Photos = ($folderFiles | Where-Object { $photoExts -contains $_.Extension.ToLower() }).Count
        }
    } | Sort-Object Name
    
    $report += "`nFOLDERS BY YEAR"
    $report += "-" * 40
    $report += "{0,-20} {1,10} {2,12} {3,10} {4,10}" -f "Folder", "Files", "Size (GB)", "Videos", "Photos"
    $report += "-" * 40
    foreach ($folder in $yearFolders) {
        $report += "{0,-20} {1,10} {2,12} {3,10} {4,10}" -f $folder.Name, $folder.Files, $folder.SizeGB, $folder.Videos, $folder.Photos
    }
    
    # Mobile folders
    Write-Host "  Finding Mobile folders..." -ForegroundColor Gray
    $mobileFolders = Get-ChildItem -Path $Path -Recurse -Directory -Filter "Mobile*" -ErrorAction SilentlyContinue
    
    $report += "`nMOBILE FOLDERS"
    $report += "-" * 40
    $report += "Total Mobile Folders: $($mobileFolders.Count)"
    if ($mobileFolders.Count -gt 0) {
        $mobileFiles = $mobileFolders | ForEach-Object { Get-ChildItem $_.FullName -File -ErrorAction SilentlyContinue }
        $report += "Total Files in Mobile: $($mobileFiles.Count)"
        $report += "Total Size: $([math]::Round(($mobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)) GB"
    }
    
    # Pre-2021 analysis (dirty folders)
    Write-Host "  Analyzing pre-2021 folders..." -ForegroundColor Gray
    $pre2021 = Get-ChildItem -Path $Path -Directory -Depth 0 | 
    Where-Object { $_.Name -match '^(201[0-9]|2020|2021)' } |
    ForEach-Object {
        $folderFiles = Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name   = $_.Name
            Files  = $folderFiles.Count
            SizeGB = [math]::Round(($folderFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2)
        }
    }
    
    if ($pre2021.Count -gt 0) {
        $report += "`nPRE-2021 FOLDERS (Likely Need Cleanup)"
        $report += "-" * 40
        foreach ($folder in $pre2021 | Sort-Object SizeGB -Descending) {
            $report += "  $($folder.Name): $($folder.Files) files, $($folder.SizeGB) GB"
        }
    }
    
    Write-Host "  Done!" -ForegroundColor Green
}

# Analyze both drives
Analyze-Drive -Path $RecentPath -Name "RECENT"
Analyze-Drive -Path $OldPath -Name "OLD"

# Save report
$report | Out-File -FilePath $OutputPath -Encoding UTF8
Write-Host "`n=== ANALYSIS COMPLETE ===" -ForegroundColor Green
Write-Host "Report saved to: $OutputPath" -ForegroundColor Cyan
Write-Host ""

# Display summary
Write-Host "`nQUICK SUMMARY:" -ForegroundColor Yellow
$report | Select-String -Pattern "Total Files:|Total Size:|Total Videos:|Total Photos:" | ForEach-Object { Write-Host "  $_" }
