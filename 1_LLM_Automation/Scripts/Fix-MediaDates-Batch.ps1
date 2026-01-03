# ============================================================================
# Script Name: Fix-MediaDates-Batch.ps1
# Description: Batch processes folders, using LastWriteTime as source of truth
#              for files where it's reasonable (matches folder year).
#              Updates EXIF metadata and renames files.
# Usage: .\Fix-MediaDates-Batch.ps1 -FolderPaths @("D:\2019\Lucca", ...)
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string[]]$FolderPaths,
    
    [switch]$WhatIf = $false
)

$MEDIA_EXTENSIONS = @('.jpg', '.jpeg', '.png', '.heic', '.mp4', '.mov', '.avi', '.mkv', '.m4v')

foreach ($folderPath in $FolderPaths) {
    if (-not (Test-Path $folderPath)) {
        Write-Host "`n[SKIP] Folder not found: $folderPath" -ForegroundColor Yellow
        continue
    }
    
    $folder = Get-Item $folderPath
    $folderName = $folder.Name
    
    # Extract expected year from folder path (e.g., D:\2019\... -> 2019)
    $expectedYear = $null
    if ($folder.FullName -match '\\(\d{4})\\') {
        $expectedYear = [int]$matches[1]
    }
    
    Write-Host "`n========================================================================="
    Write-Host "Processing Folder: $($folder.FullName)" -ForegroundColor Cyan
    if ($expectedYear) {
        Write-Host "Expected Year: $expectedYear" -ForegroundColor Gray
    }
    if ($WhatIf) { Write-Host "Mode: PREVIEW" -ForegroundColor Yellow }
    
    $mediaFiles = Get-ChildItem $folderPath -File -Recurse | Where-Object { 
        $MEDIA_EXTENSIONS -contains $_.Extension.ToLower() 
    } | Sort-Object LastWriteTime
    
    if ($mediaFiles.Count -eq 0) {
        Write-Host "[INFO] No media files found." -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Found $($mediaFiles.Count) media file(s)`n"
    
    $counter = 1
    $processedCount = 0
    
    foreach ($file in $mediaFiles) {
        $dateToUse = $file.LastWriteTime
        
        # Skip if date seems wrong (not matching expected year)
        if ($expectedYear -and $dateToUse.Year -ne $expectedYear) {
            Write-Host "[$counter/$($mediaFiles.Count)] [SKIP] $($file.Name) - Date mismatch (file: $($dateToUse.Year), expected: $expectedYear)" -ForegroundColor Yellow
            $counter++
            continue
        }
        
        $dateStr = $dateToUse.ToString('yyyy-MM-dd')
        $dateCompact = $dateToUse.ToString('yyyyMMdd')
        $ext = $file.Extension.ToLower()
        
        $newName = "${dateCompact}_${folderName}_$('{0:D3}' -f $counter)$ext"
        $newPath = Join-Path $file.DirectoryName $newName
        
        Write-Host "[$counter/$($mediaFiles.Count)] $($file.Name)"
        Write-Host "  Date: $dateStr (from LastWriteTime)" -ForegroundColor Gray
        
        if (-not $WhatIf) {
            # Update EXIF metadata
            $dateFormatted = $dateToUse.ToString('yyyy:MM:dd HH:mm:ss')
            
            $exifArgs = @(
                "-AllDates=$dateFormatted"
                "-DateTimeOriginal=$dateFormatted"
                "-CreateDate=$dateFormatted"
                "-ModifyDate=$dateFormatted"
                "-overwrite_original"
            )
            
            # For videos
            if ($ext -in @('.mp4', '.mov', '.avi', '.mkv', '.m4v')) {
                $exifArgs += "-TrackCreateDate=$dateFormatted"
                $exifArgs += "-TrackModifyDate=$dateFormatted"
                $exifArgs += "-MediaCreateDate=$dateFormatted"
                $exifArgs += "-MediaModifyDate=$dateFormatted"
            }
            
            $exifArgs += $file.FullName
            
            & exiftool @exifArgs > $null 2>&1
            
            # Update filesystem timestamps
            $item = Get-Item $file.FullName
            $item.CreationTime = $dateToUse
            $item.LastWriteTime = $dateToUse
            
            # Rename
            if ($file.Name -ne $newName) {
                Rename-Item $file.FullName $newName -Force
                Write-Host "  -> Renamed to: $newName" -ForegroundColor Green
            }
            else {
                Write-Host "  [OK] Already correct name" -ForegroundColor Green
            }
            
            $processedCount++
        }
        else {
            Write-Host "  [PREVIEW] Would rename to: $newName" -ForegroundColor Gray
        }
        
        $counter++
    }
    
    Write-Host "`nFolder Summary: $processedCount / $($mediaFiles.Count) files processed" -ForegroundColor Cyan
}

Write-Host "`n========================================================================="
Write-Host "Batch processing complete!" -ForegroundColor Green
