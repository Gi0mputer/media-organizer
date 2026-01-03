# ============================================================================
# Script Name: Force-DateFromReference.ps1
# Description: Uses a reference file with correct date to force ALL files in a
#              target folder to that date (single-day events, controlled cases).
# Usage:
#   .\Force-DateFromReference.ps1 -ReferencePath "E:\2024\Evento\IMG_1234.jpg" -WhatIf
#   .\Force-DateFromReference.ps1 -ReferencePath "E:\2024\Evento\Mobile\VID-20240724-WA0009.mp4"
#   .\Force-DateFromReference.ps1 -ReferencePath "...\file.jpg" -FolderPath "D:\2019\Lucca"
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ReferencePath,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$FolderPath = "",

    [switch]$WhatIf = $false,

    [switch]$Force = $false
)

$ErrorActionPreference = 'SilentlyContinue'

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp',
    '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp'
)

$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp')

$SERVICE_FOLDERS = @('mobile', 'drive', 'merge', 'raw')

function Parse-DateFromString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()

    if ($v -match '^(\d{4})-(\d{2})-(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    if ($v -match '^(\d{4}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    return $null
}

function Get-DateFromFileName {
    param([string]$Name)

    if ($Name -match '^(19\d{2}|20\d{2})(\d{2})(\d{2})_') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

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
        if ($dt) { return $dt }
    }

    return $null
}

function Resolve-TargetFolder {
    param(
        [string]$ReferenceFile,
        [string]$ExplicitFolder
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitFolder)) {
        return (Resolve-Path -LiteralPath $ExplicitFolder).Path.TrimEnd('\')
    }

    $dir = (Split-Path -Path $ReferenceFile -Parent).TrimEnd('\')

    while ($true) {
        $leaf = (Split-Path -Path $dir -Leaf).ToLowerInvariant()
        if ($SERVICE_FOLDERS -contains $leaf) {
            $parent = Split-Path -Path $dir -Parent
            if ([string]::IsNullOrWhiteSpace($parent)) { break }
            $dir = $parent.TrimEnd('\')
            continue
        }
        break
    }

    return $dir
}

# Preconditions
$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Host "[ERROR] ExifTool not found in PATH." -ForegroundColor Red
    exit 1
}

try {
    $ReferencePath = (Resolve-Path -LiteralPath $ReferencePath).Path
}
catch {
    Write-Host "[ERROR] Reference file not found: $ReferencePath" -ForegroundColor Red
    exit 1
}

$refItem = Get-Item -LiteralPath $ReferencePath
if ($refItem.PSIsContainer) {
    Write-Host "[ERROR] ReferencePath must be a FILE, not a folder." -ForegroundColor Red
    exit 1
}

try {
    $targetFolder = Resolve-TargetFolder -ReferenceFile $ReferencePath -ExplicitFolder $FolderPath
}
catch {
    Write-Host "[ERROR] Target folder not found: $FolderPath" -ForegroundColor Red
    exit 1
}

$targetLeaf = Split-Path -Path $targetFolder -Leaf
if (-not $Force -and $targetLeaf -match '^(19\d{2}|20\d{2})$') {
    Write-Host "[ERROR] Refusing to run on a YEAR folder ($targetLeaf). Use the Quarantine workflow for year roots." -ForegroundColor Red
    Write-Host "If you really want to proceed, re-run with -Force (NOT recommended)." -ForegroundColor Yellow
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FORCE DATE FROM REFERENCE (Advanced Fix)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Reference: $ReferencePath" -ForegroundColor White
Write-Host "Target folder: $targetFolder" -ForegroundColor White
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW (-WhatIf)' } else { 'EXECUTE' })"
Write-Host ""

# Determine date from reference
$refDate = Get-BestExifDate -FilePath $ReferencePath
if (-not $refDate) {
    $refDate = Get-DateFromFileName -Name $refItem.Name
}

if (-not $refDate) {
    Write-Host "[WARN] Could not read date from reference metadata/filename." -ForegroundColor Yellow
    $manual = Read-Host "Enter date (YYYY-MM-DD)"
    if ($manual -notmatch '^\d{4}-\d{2}-\d{2}$') {
        Write-Host "[ERROR] Invalid date format." -ForegroundColor Red
        exit 1
    }
    $parts = $manual -split '-'
    $refDate = Get-Date -Year ([int]$parts[0]) -Month ([int]$parts[1]) -Day ([int]$parts[2]) -Hour 12 -Minute 0 -Second 0
}

$targetDate = $refDate.Date.AddHours(12)
$targetExif = $targetDate.ToString('yyyy:MM:dd HH:mm:ss')

Write-Host "Detected reference date: $($refDate.ToString('yyyy-MM-dd'))" -ForegroundColor Green
Write-Host "Target applied date/time: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
Write-Host ""

$mediaFiles = Get-ChildItem -LiteralPath $targetFolder -File -Recurse -ErrorAction SilentlyContinue |
Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLowerInvariant() }

if (-not $mediaFiles -or $mediaFiles.Count -eq 0) {
    Write-Host "[ERROR] No media files found in target folder." -ForegroundColor Red
    exit 1
}

Write-Host "Found $($mediaFiles.Count) media file(s) to update" -ForegroundColor Green

# Report (project-local)
$reportPath = "c:\Users\ASUS\Desktop\Batchs\1_LLM_Automation\Analysis\DATE_FIX_REFERENCE_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
$report = @()
$report += "# Date Fix Report - Force from Reference"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Reference: $ReferencePath"
$report += "TargetFolder: $targetFolder"
$report += "TargetDate: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))"
$report += ""
$report += "## Summary"
$report += "- Total files: $($mediaFiles.Count)"
$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host ""

if (-not $WhatIf) {
    $ans = Read-Host "Apply this date to ALL $($mediaFiles.Count) file(s)? Type YES to proceed"
    if ($ans -ne 'YES') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

$ok = 0
$fail = 0
$idx = 0
foreach ($f in $mediaFiles) {
    $idx++
    Write-Host "[$idx/$($mediaFiles.Count)] $($f.Name)" -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "  [PREVIEW] Would set metadata dates to: $targetExif" -ForegroundColor Gray
        Write-Host "  [PREVIEW] Would set filesystem times to: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
        continue
    }

    $ext = $f.Extension.ToLowerInvariant()
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

    $exifArgs += $f.FullName

    & exiftool @exifArgs > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] ExifTool failed (code $LASTEXITCODE)" -ForegroundColor Red
        $fail++
        continue
    }

    try {
        $fi = Get-Item -LiteralPath $f.FullName
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
