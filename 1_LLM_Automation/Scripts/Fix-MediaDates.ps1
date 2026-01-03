# ============================================================================
# Script Name: Fix-MediaDates.ps1
# Description: Fixes EXIF/metadata dates for photos and videos using GPS data
#              or user input. Renames files with standardized format.
#              Perfect for preparing media for Google Photos upload.
# Usage: .\Fix-MediaDates.ps1 -FolderPath "D:\2019\CamperAlby"
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$FolderPath,
    
    [string]$TargetDate = "",  # Format: YYYY-MM-DD or leave empty to auto-detect
    
    [switch]$Rename = $true,   # Rename files with YYYYMMDD_FolderName_NNN.ext
    
    [switch]$WhatIf = $false,  # Preview mode, no changes
    
    [switch]$Backup = $false   # Create .original backup files
)

$MEDIA_EXTENSIONS = @('.jpg', '.jpeg', '.png', '.heic', '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv')

# Check ExifTool availability
$exiftoolPath = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftoolPath) {
    Write-Host "[ERROR] ExifTool not found. Please install ExifTool." -ForegroundColor Red
    exit 1
}

# Validate folder
if (-not (Test-Path $FolderPath)) {
    Write-Host "[ERROR] Folder not found: $FolderPath" -ForegroundColor Red
    exit 1
}

$folder = Get-Item $FolderPath
$folderName = $folder.Name

Write-Host "=== MEDIA DATE FIX TOOL ===" -ForegroundColor Cyan
Write-Host "Folder: $($folder.FullName)" -ForegroundColor White
if ($WhatIf) { Write-Host "Mode: PREVIEW (no changes)" -ForegroundColor Yellow }
Write-Host ""

# Scan for media files
$mediaFiles = Get-ChildItem $FolderPath -File | Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLower() }

if ($mediaFiles.Count -eq 0) {
    Write-Host "[ERROR] No media files found in folder." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($mediaFiles.Count) media file(s)" -ForegroundColor Green
Write-Host ""

# Auto-detect date from GPS/EXIF if not provided
if ([string]::IsNullOrEmpty($TargetDate)) {
    Write-Host "[INFO] Auto-detecting date from GPS/EXIF metadata..." -ForegroundColor Yellow
    
    foreach ($file in $mediaFiles) {
        $exifOutput = & exiftool -GPSDateTime -DateTimeOriginal -CreateDate -s3 $file.FullName 2>$null
        
        if ($exifOutput) {
            $lines = $exifOutput -split "`n"
            foreach ($line in $lines) {
                if ($line -match '(\d{4}):(\d{2}):(\d{2})') {
                    $detectedDate = "$($matches[1])-$($matches[2])-$($matches[3])"
                    Write-Host "  [FOUND] GPS/EXIF Date in $($file.Name): $detectedDate" -ForegroundColor Green
                    $TargetDate = $detectedDate
                    break
                }
            }
        }
        
        if (-not [string]::IsNullOrEmpty($TargetDate)) { break }
    }
    
    if ([string]::IsNullOrEmpty($TargetDate)) {
        Write-Host "[WARN] No GPS/EXIF date found. Please enter date manually." -ForegroundColor Yellow
        $TargetDate = Read-Host "Enter date (YYYY-MM-DD)"
    }
    else {
        Write-Host "[INFO] Using detected date: $TargetDate" -ForegroundColor Cyan
        $confirm = Read-Host "Use this date for all files? (Y/n)"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            $TargetDate = Read-Host "Enter date (YYYY-MM-DD)"
        }
    }
}

# Validate date format
if ($TargetDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
    Write-Host "[ERROR] Invalid date format. Use YYYY-MM-DD" -ForegroundColor Red
    exit 1
}

$dateParts = $TargetDate -split '-'
$dateFormatted = $TargetDate -replace '-', ':'  # EXIF format: YYYY:MM:DD
$dateCompact = $TargetDate -replace '-', ''     # For filename: YYYYMMDD

Write-Host ""
Write-Host "Target Date: $TargetDate" -ForegroundColor Cyan
Write-Host "Rename Format: ${dateCompact}_${folderName}_NNN.ext" -ForegroundColor Cyan
Write-Host ""

$counter = 1
$processedCount = 0

foreach ($file in $mediaFiles) {
    $ext = $file.Extension.ToLower()
    $newName = "${dateCompact}_${folderName}_$('{0:D3}' -f $counter)$ext"
    $newPath = Join-Path $file.DirectoryName $newName
    
    Write-Host "[$counter/$($mediaFiles.Count)] $($file.Name)"
    
    if ($Rename -and -not $WhatIf) {
        Write-Host "  -> Renaming to: $newName" -ForegroundColor Yellow
    }
    
    # Backup if requested
    if ($Backup -and -not $WhatIf) {
        $backupPath = "$($file.FullName).original"
        Copy-Item $file.FullName $backupPath -Force
        Write-Host "  [BACKUP] Created: $($file.Name).original" -ForegroundColor Gray
    }
    
    # Update EXIF metadata
    $exifArgs = @(
        "-AllDates=$dateFormatted 12:00:00"
        "-DateTimeOriginal=$dateFormatted 12:00:00"
        "-CreateDate=$dateFormatted 12:00:00"
        "-ModifyDate=$dateFormatted 12:00:00"
        "-overwrite_original"
    )
    
    # For videos, also set track/media dates
    if ($ext -in @('.mp4', '.mov', '.avi', '.mkv', '.m4v')) {
        $exifArgs += "-TrackCreateDate=$dateFormatted 12:00:00"
        $exifArgs += "-TrackModifyDate=$dateFormatted 12:00:00"
        $exifArgs += "-MediaCreateDate=$dateFormatted 12:00:00"
        $exifArgs += "-MediaModifyDate=$dateFormatted 12:00:00"
    }
    
    $exifArgs += $file.FullName
    
    if (-not $WhatIf) {
        Write-Host "  [EXIF] Updating metadata..." -ForegroundColor Cyan
        & exiftool @exifArgs > $null 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Metadata updated" -ForegroundColor Green
        }
        else {
            Write-Host "  [WARN] ExifTool returned error code $LASTEXITCODE" -ForegroundColor Yellow
        }
        
        # Update filesystem timestamps
        $dateObj = [DateTime]::ParseExact($TargetDate, 'yyyy-MM-dd', $null).AddHours(12)
        $item = Get-Item $file.FullName
        $item.CreationTime = $dateObj
        $item.LastWriteTime = $dateObj
        
        # Rename file
        if ($Rename) {
            Rename-Item $file.FullName $newName -Force
            Write-Host "  [OK] Renamed" -ForegroundColor Green
        }
        
        $processedCount++
    }
    else {
        Write-Host "  [PREVIEW] Would update EXIF to: $dateFormatted 12:00:00" -ForegroundColor Gray
        if ($Rename) {
            Write-Host "  [PREVIEW] Would rename to: $newName" -ForegroundColor Gray
        }
    }
    
    $counter++
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "Preview complete. Run without -WhatIf to apply changes." -ForegroundColor Yellow
}
else {
    Write-Host "Successfully processed $processedCount / $($mediaFiles.Count) files!" -ForegroundColor Green
}
