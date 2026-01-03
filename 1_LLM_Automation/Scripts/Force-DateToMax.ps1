# ============================================================================
# Script Name: Force-DateToMax.ps1
# Description: Detects the valid date range of an event folder (GPS/EXIF first)
#              and forces anomalous files to the MAX date (end of interval),
#              so they appear at the end in gallery timelines.
# Usage:
#   .\Force-DateToMax.ps1 -FolderPath "D:\2019\SpagnaCalaLevado" -WhatIf
#   .\Force-DateToMax.ps1 -FolderPath "D:\2019\SpagnaCalaLevado"
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FolderPath,

    [switch]$WhatIf = $false,

    [switch]$Force = $false,

    [int]$MaxRangeDays = 60,

    [switch]$IncludeUnknown = $false
)

$ErrorActionPreference = 'SilentlyContinue'

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp',
    '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp'
)

$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp')

$SERVICE_FOLDERS = @('mobile', 'drive', 'merge', 'raw')

$VALID_YEAR_MIN = 2001
$VALID_YEAR_MAX = (Get-Date).Year + 1

function Get-ExpectedYearFromPath {
    param([string]$Path)
    $p = $Path.TrimEnd('\')
    $segments = $p -split '\\'
    foreach ($seg in $segments) {
        if ($seg -match '^(19\d{2}|20\d{2})$') { return [int]$seg }
    }
    return $null
}

function Parse-DateFromString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()

    # Handle exiftool output formatted with -d "%Y-%m-%d %H:%M:%S" (timezone may be appended)
    if ($v -match '^(\d{4})-(\d{2})-(\d{2})') {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]
            if ($y -lt 1900 -or $y -gt 2100) { return $null }
            if ($m -lt 1 -or $m -gt 12) { return $null }
            if ($d -lt 1 -or $d -gt 31) { return $null }
            return Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    # Also accept YYYY:MM:DD
    if ($v -match '^(\d{4}):(\d{2}):(\d{2})') {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]
            return Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    return $null
}

function Get-DateFromFileName {
    param([string]$Name)

    # Standard archive naming: YYYYMMDD_...
    if ($Name -match '^(19\d{2}|20\d{2})(\d{2})(\d{2})_') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    # Common phone/WA patterns: IMG_20240723_..., VID-20240724-WA0009, etc.
    if ($Name -match '(19\d{2}|20\d{2})(\d{2})(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    return $null
}

function Get-BestExifDate {
    param([string]$FilePath)

    $tagOrder = @('GPSDateTime', 'DateTimeOriginal', 'MediaCreateDate', 'TrackCreateDate', 'CreateDate')
    $tagConfidence = @{
        'GPSDateTime' = 3
        'DateTimeOriginal' = 3
        'MediaCreateDate' = 2
        'TrackCreateDate' = 2
        'CreateDate' = 2
    }

    $args = @(
        '-s2',
        '-d', '%Y-%m-%d %H:%M:%S',
        '-GPSDateTime',
        '-DateTimeOriginal',
        '-MediaCreateDate',
        '-TrackCreateDate',
        '-CreateDate',
        '-api', 'QuickTimeUTC',
        $FilePath
    )

    $lines = & exiftool @args 2>$null
    if (-not $lines) { return $null }

    $map = @{}
    foreach ($line in $lines) {
        if ($line -match '^(\w+)\s*:\s*(.*)$') {
            $tag = $matches[1]
            $val = $matches[2].Trim()
            if (-not [string]::IsNullOrWhiteSpace($val)) {
                $map[$tag] = $val
            }
        }
    }

    foreach ($tag in $tagOrder) {
        if (-not $map.ContainsKey($tag)) { continue }
        $dt = Parse-DateFromString -Value $map[$tag]
        if ($dt) {
            return [pscustomobject]@{
                Date       = $dt
                Source     = $tag
                Confidence = $tagConfidence[$tag]
            }
        }
    }

    return $null
}

function Get-BestDateForFile {
    param(
        [System.IO.FileInfo]$FileItem,
        [int]$ExpectedYear
    )

    $exif = Get-BestExifDate -FilePath $FileItem.FullName
    if ($exif) {
        if ($exif.Date.Year -ge $VALID_YEAR_MIN -and $exif.Date.Year -le $VALID_YEAR_MAX) {
            return $exif
        }
    }

    $fn = Get-DateFromFileName -Name $FileItem.Name
    if ($fn) {
        if ($fn.Year -ge $VALID_YEAR_MIN -and $fn.Year -le $VALID_YEAR_MAX) {
            return [pscustomobject]@{
                Date       = $fn
                Source     = 'FileName'
                Confidence = 2
            }
        }
    }

    $lw = $FileItem.LastWriteTime
    if ($lw.Year -ge $VALID_YEAR_MIN -and $lw.Year -le $VALID_YEAR_MAX) {
        if (-not $ExpectedYear -or $lw.Year -eq $ExpectedYear) {
            return [pscustomobject]@{
                Date       = (Get-Date -Year $lw.Year -Month $lw.Month -Day $lw.Day -Hour 12 -Minute 0 -Second 0)
                Source     = 'LastWriteTime'
                Confidence = 1
            }
        }
    }

    return $null
}

# Preconditions
$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Host "[ERROR] ExifTool not found in PATH." -ForegroundColor Red
    exit 1
}

try {
    $FolderPath = (Resolve-Path -LiteralPath $FolderPath).Path.TrimEnd('\')
}
catch {
    Write-Host "[ERROR] Folder not found: $FolderPath" -ForegroundColor Red
    exit 1
}

$folderItem = Get-Item -LiteralPath $FolderPath
if (-not $folderItem.PSIsContainer) {
    Write-Host "[ERROR] Not a folder: $FolderPath" -ForegroundColor Red
    exit 1
}

$leaf = Split-Path -Path $FolderPath -Leaf
if (-not $Force -and $leaf -match '^(19\d{2}|20\d{2})$') {
    Write-Host "[ERROR] Refusing to run on a YEAR folder ($leaf). Use Quarantine workflow for year roots." -ForegroundColor Red
    Write-Host "If you really want to proceed, re-run with -Force (NOT recommended)." -ForegroundColor Yellow
    exit 1
}

$expectedYear = Get-ExpectedYearFromPath -Path $FolderPath

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FORCE DATE TO MAX (Advanced Fix)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Folder: $FolderPath"
if ($expectedYear) { Write-Host "Expected Year (from path): $expectedYear" -ForegroundColor Gray }
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW (-WhatIf)' } else { 'EXECUTE' })"
Write-Host ""

$mediaFiles = Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue |
Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLowerInvariant() }

if (-not $mediaFiles -or $mediaFiles.Count -eq 0) {
    Write-Host "[ERROR] No media files found." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($mediaFiles.Count) media file(s)" -ForegroundColor Green
Write-Host "[INFO] Reading dates (ExifTool)... this may take a moment." -ForegroundColor Yellow
Write-Host ""

$items = foreach ($f in $mediaFiles) {
    $best = Get-BestDateForFile -FileItem $f -ExpectedYear $expectedYear
    [pscustomobject]@{
        File       = $f.FullName
        Name       = $f.Name
        Extension  = $f.Extension.ToLowerInvariant()
        BestDate   = if ($best) { $best.Date } else { $null }
        Source     = if ($best) { $best.Source } else { 'Unknown' }
        Confidence = if ($best) { $best.Confidence } else { 0 }
        LastWrite  = $f.LastWriteTime
    }
}

$eligible = $items | Where-Object { $_.BestDate -ne $null }
if ($expectedYear) { $eligible = $eligible | Where-Object { $_.BestDate.Year -eq $expectedYear } }

if (-not $eligible -or $eligible.Count -lt 2) {
    Write-Host "[ERROR] Not enough valid dates to detect a reliable range." -ForegroundColor Red
    Write-Host "Suggestion: Use Force-DateFromReference.ps1 (reference file) for this folder." -ForegroundColor Yellow
    exit 1
}

$maxConf = ($eligible | Measure-Object -Property Confidence -Maximum).Maximum
$rangeSet = $eligible | Where-Object { $_.Confidence -eq $maxConf }
if ($rangeSet.Count -lt 2) {
    $rangeSet = $eligible | Where-Object { $_.Confidence -ge ([math]::Max(1, $maxConf - 1)) }
}

$minDate = ($rangeSet | Sort-Object -Property BestDate | Select-Object -First 1).BestDate
$maxDate = ($rangeSet | Sort-Object -Property BestDate | Select-Object -Last 1).BestDate
$spanDays = [int]([math]::Round(($maxDate.Date - $minDate.Date).TotalDays))

if (-not $Force -and $spanDays -gt $MaxRangeDays) {
    Write-Host "[ERROR] Detected range is too wide ($spanDays days > $MaxRangeDays)." -ForegroundColor Red
    Write-Host "This looks like a YEAR folder or mixed content. Use the Quarantine workflow instead." -ForegroundColor Yellow
    Write-Host "If you really want to proceed, re-run with -Force." -ForegroundColor Yellow
    exit 1
}

$targetDate = $maxDate.Date.AddHours(23).AddMinutes(59).AddSeconds(0)
$targetExif = $targetDate.ToString('yyyy:MM:dd HH:mm:ss')

Write-Host "Detected valid range (from confidence $maxConf sources):" -ForegroundColor Cyan
Write-Host "  MIN: $($minDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "  MAX: $($maxDate.ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "  SPAN: $spanDays day(s)" -ForegroundColor Gray
Write-Host "Target MAX (forced): $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host ""

$anomalies = $items | Where-Object {
    if ($_.BestDate -eq $null) { return $IncludeUnknown }

    if ($expectedYear -and $_.BestDate.Year -ne $expectedYear) { return $true }
    if ($_.BestDate.Year -lt $VALID_YEAR_MIN -or $_.BestDate.Year -gt $VALID_YEAR_MAX) { return $true }
    if ($_.BestDate.Date -lt $minDate.Date) { return $true }
    if ($_.BestDate.Date -gt $maxDate.Date) { return $true }
    return $false
}

Write-Host "Anomalous files detected: $($anomalies.Count)" -ForegroundColor Yellow
if ($anomalies.Count -gt 0) {
    $anomalies | Select-Object -First 20 | ForEach-Object {
        $bd = if ($_.BestDate) { $_.BestDate.ToString('yyyy-MM-dd') } else { 'UNKNOWN' }
        Write-Host "  - $($_.Name)  [$bd, $($_.Source)]" -ForegroundColor Gray
    }
    if ($anomalies.Count -gt 20) { Write-Host "  ... +$($anomalies.Count - 20) more" -ForegroundColor Gray }
}
else {
    Write-Host "[OK] No anomalies found. Nothing to do." -ForegroundColor Green
    exit 0
}

# Report (project-local, no archive pollution)
$reportPath = "c:\Users\ASUS\Desktop\Batchs\1_LLM_Automation\Analysis\DATE_FIX_MAX_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
$report = @()
$report += "# Date Fix Report - Force to MAX"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Folder: $FolderPath"
if ($expectedYear) { $report += "ExpectedYear: $expectedYear" }
$report += "DetectedRange: $($minDate.ToString('yyyy-MM-dd')) -> $($maxDate.ToString('yyyy-MM-dd')) (Span: $spanDays days)"
$report += "TargetMax: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += ""
$report += "## Summary"
$report += "- Total files: $($items.Count)"
$report += "- Eligible (range): $($eligible.Count)"
$report += "- Anomalies: $($anomalies.Count)"
$report += ""
$report += "## Anomalies"
foreach ($a in $anomalies) {
    $bd = if ($a.BestDate) { $a.BestDate.ToString('yyyy-MM-dd') } else { 'UNKNOWN' }
    $report += "- `$($a.File)` | $bd | $($a.Source)"
}
$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host ""

if (-not $WhatIf) {
    $ans = Read-Host "Apply MAX date to $($anomalies.Count) file(s)? Type YES to proceed"
    if ($ans -ne 'YES') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

$ok = 0
$fail = 0
$index = 0
foreach ($a in $anomalies) {
    $index++
    Write-Host "[$index/$($anomalies.Count)] $($a.Name)" -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [PREVIEW] Would set metadata dates to: $targetExif" -ForegroundColor Gray
        Write-Host "  [PREVIEW] Would set filesystem times to: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        continue
    }

    $ext = $a.Extension
    $exifArgs = @(
        "-AllDates=$targetExif"
        "-DateTimeOriginal=$targetExif"
        "-CreateDate=$targetExif"
        "-ModifyDate=$targetExif"
        "-overwrite_original"
    )

    if ($VIDEO_EXTENSIONS -contains $ext) {
        $exifArgs += "-TrackCreateDate=$targetExif"
        $exifArgs += "-TrackModifyDate=$targetExif"
        $exifArgs += "-MediaCreateDate=$targetExif"
        $exifArgs += "-MediaModifyDate=$targetExif"
    }

    $exifArgs += $a.File

    & exiftool @exifArgs > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] ExifTool failed (code $LASTEXITCODE)" -ForegroundColor Red
        $fail++
        continue
    }

    try {
        $fi = Get-Item -LiteralPath $a.File
        $fi.CreationTime = $targetDate
        $fi.LastWriteTime = $targetDate
        $ok++
        Write-Host "  [OK] Updated" -ForegroundColor Green
    }
    catch {
        $fail++
        Write-Host "  [WARN] Metadata updated but failed to set filesystem times" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Done. Updated: $ok   Failed: $fail" -ForegroundColor Cyan
