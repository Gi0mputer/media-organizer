param(
    [string]$TargetPath = "E:\",
    [string[]]$YearFolders = @("2018 e pre", "2019", "2020", "2021")
)

Write-Host "=== METADATA & FORMAT ANALYSIS (OLD FOLDERS) ===" -ForegroundColor Cyan
Write-Host ""

$videoExts = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.MOV')
$photoExts = @('.jpg', '.jpeg', '.png', '.heic', '.JPG', '.JPEG')

foreach ($yearFolder in $YearFolders) {
    $folderPath = Join-Path $TargetPath $yearFolder
    
    if (-not (Test-Path $folderPath)) {
        Write-Host "[SKIP] $yearFolder - not found" -ForegroundColor Gray
        continue
    }
    
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "ANALYZING: $yearFolder" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    # Get all media files
    $allFiles = Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue
    $videos = $allFiles | Where-Object { $videoExts -contains $_.Extension }
    $photos = $allFiles | Where-Object { $photoExts -contains $_.Extension }
    
    Write-Host "`nFILE SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Total files: $($allFiles.Count)"
    Write-Host "  Videos: $($videos.Count)"
    Write-Host "  Photos: $($photos.Count)"
    
    # Video format analysis
    if ($videos.Count -gt 0) {
        Write-Host "`nVIDEO FORMATS:" -ForegroundColor Cyan
        $videos | Group-Object Extension | Sort-Object Count -Descending | ForEach-Object {
            $sizeGB = [math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1GB, 2)
            Write-Host "  $($_.Name): $($_.Count) files, $sizeGB GB"
        }
        
        # Check for WhatsApp files
        $whatsappVids = $videos | Where-Object { 
            $_.Name -match "WhatsApp|WA\d{4}|VID-\d{8}-WA\d{4}" 
        }
        if ($whatsappVids.Count -gt 0) {
            Write-Host "`n  [!] WhatsApp videos found: $($whatsappVids.Count)" -ForegroundColor Red
            Write-Host "      Total size: $([math]::Round(($whatsappVids | Measure-Object Length -Sum).Sum / 1MB, 2)) MB"
        }
    }
    
    # Photo analysis
    if ($photos.Count -gt 0) {
        Write-Host "`nPHOTO FORMATS:" -ForegroundColor Cyan
        $photos | Group-Object Extension | Sort-Object Count -Descending | ForEach-Object {
            $sizeMB = [math]::Round(($_.Group | Measure-Object Length -Sum).Sum / 1MB, 2)
            Write-Host "  $($_.Name): $($_.Count) files, $sizeMB MB"
        }
        
        # Check for WhatsApp photos
        $whatsappPhotos = $photos | Where-Object { 
            $_.Name -match "WhatsApp|WA\d{4}|IMG-\d{8}-WA\d{4}" 
        }
        if ($whatsappPhotos.Count -gt 0) {
            Write-Host "`n  [!] WhatsApp photos found: $($whatsappPhotos.Count)" -ForegroundColor Red
            Write-Host "      Total size: $([math]::Round(($whatsappPhotos | Measure-Object Length -Sum).Sum / 1MB, 2)) MB"
        }
    }
    
    # Metadata analysis (sampling)
    Write-Host "`nMETADATA SAMPLING (first 100 videos):" -ForegroundColor Cyan
    $sampleVids = $videos | Select-Object -First 100
    
    if ($sampleVids.Count -gt 0) {
        # File dates vs actual content
        $hasFileDate = 0
        $dateRange = @{Min = [datetime]::MaxValue; Max = [datetime]::MinValue }
        
        foreach ($vid in $sampleVids) {
            if ($vid.CreationTime) {
                $hasFileDate++
                if ($vid.CreationTime -lt $dateRange.Min) { $dateRange.Min = $vid.CreationTime }
                if ($vid.CreationTime -gt $dateRange.Max) { $dateRange.Max = $vid.CreationTime }
            }
        }
        
        Write-Host "  Files with CreationTime: $hasFileDate / $($sampleVids.Count)"
        if ($hasFileDate -gt 0) {
            Write-Host "  Date range: $($dateRange.Min.ToString('yyyy-MM-dd')) to $($dateRange.Max.ToString('yyyy-MM-dd'))"
            $span = ($dateRange.Max - $dateRange.Min).Days
            Write-Host "  Span: $span days"
            
            if ($span -le 1) {
                Write-Host "  [SINGLE EVENT] - 1 day" -ForegroundColor Green
            }
            elseif ($span -le 7) {
                Write-Host "  [SHORT PERIOD] - 2-7 days" -ForegroundColor Yellow
            }
            elseif ($span -le 30) {
                Write-Host "  [MEDIUM PERIOD] - 1 month" -ForegroundColor Yellow
            }
            else {
                Write-Host "  [LONG PERIOD / RANDOM] - $span days" -ForegroundColor Red
            }
        }
    }
    
    # Check for merged/cut files (potential duplicates)
    $mergedFiles = $allFiles | Where-Object { $_.Name -match "merged|cut|-\d{13,}" }
    if ($mergedFiles.Count -gt 0) {
        Write-Host "`n  [!] Merged/Cut files found: $($mergedFiles.Count)" -ForegroundColor Magenta
        Write-Host "      (Potential duplicates to review)"
    }
    
    # Subfolder analysis
    Write-Host "`nSUBFOLDERS:" -ForegroundColor Cyan
    $subfolders = Get-ChildItem -Path $folderPath -Directory -ErrorAction SilentlyContinue
    Write-Host "  Total subfolders: $($subfolders.Count)"
    
    # Show top 5 largest subfolders
    $largestSubs = $subfolders | ForEach-Object {
        $subFiles = Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Name   = $_.Name
            Files  = $subFiles.Count
            SizeGB = [math]::Round(($subFiles | Measure-Object Length -Sum).Sum / 1GB, 2)
        }
    } | Sort-Object SizeGB -Descending | Select-Object -First 5
    
    if ($largestSubs) {
        Write-Host "  Top 5 largest:"
        foreach ($sub in $largestSubs) {
            Write-Host "    $($sub.Name): $($sub.Files) files, $($sub.SizeGB) GB"
        }
    }
}

Write-Host "`n`n=== ANALYSIS COMPLETE ===" -ForegroundColor Green
