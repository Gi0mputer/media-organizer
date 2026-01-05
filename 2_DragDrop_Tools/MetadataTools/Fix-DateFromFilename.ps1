# ============================================================================
# Script Name: Fix-DateFromFilename.ps1
# Description: Fixes media metadata + filesystem timestamps by parsing a date
#              from the filename (YYYYMMDD, optionally with HHMMSS).
#              Designed for cases where editors (e.g. Windows Photos) reset
#              dates to "today", causing wrong gallery order.
# Usage:
#   Drag & drop files/folders onto FIX_DATE_FROM_FILENAME.bat
#   Or:
#     .\Fix-DateFromFilename.ps1 "E:\2025\Liguria\PXL_20250817_115315638.mp4" -WhatIf
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$Paths,

    [switch]$WhatIf = $false,

    [switch]$Yes = $false,

    [switch]$Force = $false,

    [ValidateRange(1, 365)]
    [int]$RecentDays = 2,

    [switch]$UseTimeFromFileName = $false,

    [switch]$NoRecurse = $false
)

$ErrorActionPreference = 'SilentlyContinue'

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp',
    '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp'
)

$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp')

function Get-RepoRoot {
    param([string]$Start)
    try {
        return (Resolve-Path -LiteralPath (Join-Path $Start '..\..')).Path.TrimEnd('\')
    }
    catch {
        return (Get-Location).Path.TrimEnd('\')
    }
}

function Parse-DateFromFileName {
    param(
        [string]$BaseName,
        [switch]$UseTime
    )

    if ([string]::IsNullOrWhiteSpace($BaseName)) { return $null }

    # Common patterns:
    # - PXL_20250817_115315638  -> date + time
    # - IMG_20240723_123456     -> date + time
    # - Screenshot_2024-03-08-22-33-18-189... -> date (and sometimes time) with separators
    # - VID-20240724-WA0009     -> date only
    # - 20260103_Evento_1       -> date only (archive format)
    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})') {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]
            $hh = [int]$matches[4]
            $mm = [int]$matches[5]
            $ss = [int]$matches[6]

            if ($UseTime) {
                return Get-Date -Year $y -Month $m -Day $d -Hour $hh -Minute $mm -Second $ss
            }

            return Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    # YYYY-MM-DD (optionally with -HH-MM-SS) anywhere in name
    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})[-_](\d{2})[-_](\d{2})(?:[-_](\d{2})[-_](\d{2})[-_](\d{2}))?') {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]

            if ($UseTime -and $matches[4] -and $matches[5] -and $matches[6]) {
                $hh = [int]$matches[4]
                $mm = [int]$matches[5]
                $ss = [int]$matches[6]
                return Get-Date -Year $y -Month $m -Day $d -Hour $hh -Minute $mm -Second $ss
            }

            return Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
        }
        catch { return $null }
    }

    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})(?!\d)') {
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

function Is-RecentByFilesystem {
    param(
        [System.IO.FileInfo]$FileItem,
        [datetime]$Today,
        [datetime]$Cutoff
    )
    $c = $FileItem.CreationTime.Date
    $w = $FileItem.LastWriteTime.Date
    return (($c -ge $Cutoff -and $c -le $Today) -or ($w -ge $Cutoff -and $w -le $Today))
}

# Preconditions
$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Host "[ERROR] ExifTool not found in PATH." -ForegroundColor Red
    exit 1
}

$today = (Get-Date).Date
$cutoff = $today.AddDays(-([math]::Max(0, ($RecentDays - 1))))

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FIX DATE FROM FILENAME (Drag&Drop)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
$safetyLabel = if ($Force) { 'FORCE (all matched files)' } else { "ONLY files dated in last $RecentDays day(s) (filesystem)" }
Write-Host "Mode: $(if ($WhatIf) { 'PREVIEW (-WhatIf)' } else { 'EXECUTE' })"
Write-Host "Safety: $safetyLabel"
Write-Host "Time: $(if ($UseTimeFromFileName) { 'Use HHMMSS from filename when present' } else { 'Force 12:00:00 (safe)' })"
Write-Host ""

# Collect files
$files = @()
foreach ($p in $Paths) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }

    $resolved = $null
    try { $resolved = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path }
    catch {
        Write-Host "[WARN] Path not found: $p" -ForegroundColor Yellow
        continue
    }

    $item = Get-Item -LiteralPath $resolved -ErrorAction SilentlyContinue
    if (-not $item) { continue }

    if ($item.PSIsContainer) {
        $gciArgs = @{
            LiteralPath = $item.FullName
            File        = $true
            ErrorAction = 'SilentlyContinue'
        }
        if (-not $NoRecurse) { $gciArgs['Recurse'] = $true }

        $folderFiles = Get-ChildItem @gciArgs |
        Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLowerInvariant() }

        $files += $folderFiles
    }
    else {
        if ($MEDIA_EXTENSIONS -contains $item.Extension.ToLowerInvariant()) {
            $files += $item
        }
    }
}

$files = $files | Sort-Object -Property FullName -Unique

if (-not $files -or $files.Count -eq 0) {
    Write-Host "[ERROR] No supported media files found in input." -ForegroundColor Red
    exit 1
}

Write-Host "Input media files: $($files.Count)" -ForegroundColor Green

# Build change set
$changes = @()
$skippedNoDate = 0
$skippedNotRecent = 0

foreach ($f in $files) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $target = Parse-DateFromFileName -BaseName $base -UseTime:$UseTimeFromFileName
    if (-not $target) {
        $skippedNoDate++
        continue
    }

    if (-not $Force) {
        if (-not (Is-RecentByFilesystem -FileItem $f -Today $today -Cutoff $cutoff)) {
            $skippedNotRecent++
            continue
        }
    }

    $changes += [pscustomobject]@{
        File       = $f
        TargetDate = $target
    }
}

if (-not $changes -or $changes.Count -eq 0) {
    Write-Host ""
    Write-Host "[INFO] Nothing to fix." -ForegroundColor Yellow
    Write-Host "- Skipped (no date in filename): $skippedNoDate" -ForegroundColor Gray
    Write-Host "- Skipped (not recent): $skippedNotRecent" -ForegroundColor Gray
    Write-Host ""
    Write-Host "If you want to apply to ALL files with a parsable filename date, re-run with -Force." -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Will update: $($changes.Count) file(s)" -ForegroundColor Cyan
Write-Host "- Skipped (no date in filename): $skippedNoDate" -ForegroundColor Gray
Write-Host "- Skipped (not recent): $skippedNotRecent" -ForegroundColor Gray

# Report
$repoRoot = Get-RepoRoot -Start $PSScriptRoot
$analysisDir = Join-Path $repoRoot '1_LLM_Automation\Analysis'
if (-not (Test-Path -LiteralPath $analysisDir)) {
    try { New-Item -ItemType Directory -Path $analysisDir -Force | Out-Null } catch {}
}
$reportPath = Join-Path $analysisDir ("DATE_FIX_FILENAME_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$report = @()
$report += "# Date Fix Report - From Filename"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($WhatIf) { 'PREVIEW' } else { 'EXECUTE' })"
$report += "Force: $Force"
$report += "RecentDays: $RecentDays"
$report += "UseTimeFromFileName: $UseTimeFromFileName"
$report += ""
$report += "## Summary"
$report += "- Input media files: $($files.Count)"
$report += "- Will update: $($changes.Count)"
$report += "- Skipped (no date in filename): $skippedNoDate"
$report += "- Skipped (not recent): $skippedNotRecent"
$report += ""
$report += "## Planned Changes"
foreach ($c in $changes) {
    $f = $c.File
    $t = $c.TargetDate
    $report += "- $($f.FullName) -> $($t.ToString('yyyy-MM-dd HH:mm:ss'))"
}
$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "Report: $reportPath" -ForegroundColor Green
Write-Host ""

if (-not $WhatIf -and (-not $Yes)) {
    $ans = Read-Host "Type YES to apply changes to $($changes.Count) file(s)"
    if ($ans -ne 'YES') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

$ok = 0
$fail = 0
$idx = 0
foreach ($c in $changes) {
    $idx++
    $f = $c.File
    $targetDate = $c.TargetDate
    $targetExif = $targetDate.ToString('yyyy:MM:dd HH:mm:ss')
    $ext = $f.Extension.ToLowerInvariant()

    Write-Host "[$idx/$($changes.Count)] $($f.Name)" -ForegroundColor Cyan
    Write-Host "  Target: $($targetDate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

    if ($WhatIf) {
        Write-Host "  [PREVIEW] Would update metadata + filesystem timestamps" -ForegroundColor DarkGray
        continue
    }

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
Write-Host "Report: $reportPath" -ForegroundColor Cyan
