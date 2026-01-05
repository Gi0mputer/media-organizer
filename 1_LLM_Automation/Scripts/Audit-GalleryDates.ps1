# ============================================================================
# Script Name: Audit-GalleryDates.ps1
# Project: Media Archive Management
# Purpose:
#   Audit all PC `_gallery` / `Gallery` folders and report date/metadata issues
#   that would affect Google Photos ordering after sync.
#
# Notes:
#   - Non-destructive (read-only). Produces a Markdown report in
#     `1_LLM_Automation\\Analysis\\`.
#   - Intended workflow:
#       1) Fix `1day/NDAY` markers (Process-DayMarkerFolders.ps1)
#       2) Run this audit on E:\2024 + E:\2025
#       3) Fix issues (often with Fix-DateFromFilename.ps1 / Force-DateFromReference.ps1)
#       4) Run mobile sync
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$RootPaths,

    [ValidateRange(1, 365)]
    [int]$RecentDays = 7,

    [switch]$IncludeLegacyGallery = $true
)

$ErrorActionPreference = 'SilentlyContinue'

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp',
    '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp'
)

function Get-RepoRoot {
    param([string]$Start)
    try { return (Resolve-Path -LiteralPath (Join-Path $Start '..\..')).Path.TrimEnd('\') } catch { return (Get-Location).Path.TrimEnd('\') }
}

function Parse-DateFromFileName {
    param([string]$BaseName)
    if ([string]::IsNullOrWhiteSpace($BaseName)) { return $null }

    # date + time: 20250817_115315 or 20250817-115315
    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})') {
        try {
            $y = [int]$matches[1]; $m = [int]$matches[2]; $d = [int]$matches[3]
            $hh = [int]$matches[4]; $mm = [int]$matches[5]; $ss = [int]$matches[6]
            return (Get-Date -Year $y -Month $m -Day $d -Hour $hh -Minute $mm -Second $ss)
        } catch { return $null }
    }

    # YYYY-MM-DD (optional -HH-MM-SS) anywhere in name
    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})[-_](\d{2})[-_](\d{2})(?:[-_](\d{2})[-_](\d{2})[-_](\d{2}))?') {
        try {
            $y = [int]$matches[1]; $m = [int]$matches[2]; $d = [int]$matches[3]
            if ($matches[4] -and $matches[5] -and $matches[6]) {
                $hh = [int]$matches[4]; $mm = [int]$matches[5]; $ss = [int]$matches[6]
                return (Get-Date -Year $y -Month $m -Day $d -Hour $hh -Minute $mm -Second $ss)
            }
            return (Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0)
        } catch { return $null }
    }

    # Any YYYYMMDD in name
    if ($BaseName -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})(?!\d)') {
        try {
            $y = [int]$matches[1]; $m = [int]$matches[2]; $d = [int]$matches[3]
            return (Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0)
        } catch { return $null }
    }

    return $null
}

function Try-ParseExifDateTime {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()
    if ($v -match '^(19\d{2}|20\d{2})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
        } catch { return $null }
    }
    if ($v -match '^(19\d{2}|20\d{2}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
        } catch { return $null }
    }
    return $null
}

function Get-BestMetadataDateTime {
    param([string]$FilePath)

    $tagOrder = @('GPSDateTime', 'DateTimeOriginal', 'MediaCreateDate', 'TrackCreateDate', 'CreateDate', 'ModifyDate')
    $args = @(
        '-s2',
        '-d', '%Y-%m-%d %H:%M:%S',
        '-api', 'QuickTimeUTC=1',
        '-GPSDateTime',
        '-DateTimeOriginal',
        '-MediaCreateDate',
        '-TrackCreateDate',
        '-CreateDate',
        '-ModifyDate',
        $FilePath
    )

    $lines = & exiftool @args 2>$null
    if (-not $lines) { return $null }

    $map = @{}
    foreach ($line in $lines) {
        if ($line -match '^([A-Za-z0-9_]+)\s*:\s*(.*)$') {
            $tag = $matches[1]
            $val = $matches[2].Trim()
            if (-not [string]::IsNullOrWhiteSpace($val)) { $map[$tag] = $val }
        }
    }

    foreach ($tag in $tagOrder) {
        if (-not $map.ContainsKey($tag)) { continue }
        $dt = Try-ParseExifDateTime -Value $map[$tag]
        if ($dt) { return [pscustomobject]@{ DateTime = $dt; Source = $tag } }
    }

    return $null
}

# Preconditions
$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Host "[ERROR] ExifTool not found in PATH." -ForegroundColor Red
    exit 1
}

$repoRoot = Get-RepoRoot -Start $PSScriptRoot
$analysisDir = Join-Path $repoRoot '1_LLM_Automation\Analysis'
New-Item -ItemType Directory -Path $analysisDir -Force | Out-Null
$reportPath = Join-Path $analysisDir ("GALLERY_DATES_AUDIT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

$today = (Get-Date).Date
$fsCutoff = $today.AddDays(-([math]::Max(0, ($RecentDays - 1))))

$report = @()
$report += "# Gallery Dates Audit"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Roots: $($RootPaths -join ', ')"
$report += "RecentDays (filesystem): $RecentDays"
$report += ""

$galleryNames = @('_gallery')
if ($IncludeLegacyGallery) { $galleryNames += 'Gallery' }

$galleryDirs = @()
foreach ($root in $RootPaths) {
    if (-not (Test-Path -LiteralPath $root)) {
        $report += "## [SKIP] Root not found: $root"
        $report += ""
        continue
    }

    $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $galleryNames -contains $_.Name }

    if ($dirs) { $galleryDirs += $dirs }
}

$galleryDirs = $galleryDirs | Sort-Object FullName -Unique

$report += "## Gallery folders found: $($galleryDirs.Count)"
foreach ($d in $galleryDirs) { $report += "- $($d.FullName)" }
$report += ""

$totFiles = 0
$totErrors = 0
$totWarns = 0
$fixable = @()
$manual = @()

foreach ($dir in $galleryDirs) {
    $nestedDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -Force -ErrorAction SilentlyContinue
    $files = Get-ChildItem -LiteralPath $dir.FullName -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLowerInvariant() }

    $totFiles += $files.Count

    $report += "## $($dir.FullName)"
    $report += "- Media files (flat): $($files.Count)"
    if ($nestedDirs -and $nestedDirs.Count -gt 0) {
        $report += "- WARN: contains subfolders (sync ignores them): $($nestedDirs.Count)"
        foreach ($nd in $nestedDirs | Select-Object -First 10) { $report += "  - $($nd.Name)" }
        if ($nestedDirs.Count -gt 10) { $report += "  - ..."; }
    }
    $report += ""

    if (-not $files -or $files.Count -eq 0) { continue }

    $folderErrors = 0
    $folderWarns = 0
    $metaDates = @()
    $fnDates = @()

    foreach ($f in $files) {
        $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $fn = Parse-DateFromFileName -BaseName $base
        if ($fn) { $fnDates += $fn.Date }

        $meta = Get-BestMetadataDateTime -FilePath $f.FullName
        $metaDt = if ($meta) { [datetime]$meta.DateTime } else { $null }
        if ($metaDt) { $metaDates += $metaDt.Date }

        $issues = @()

        if (-not $metaDt) {
            $issues += 'ERROR_NO_METADATA_DATE'
        }
        else {
            $y = $metaDt.Year
            if ($y -lt 2001 -or $y -gt ((Get-Date).Year + 1)) { $issues += "ERROR_META_YEAR_WEIRD($y)" }
            if ($metaDt.Date -ge $today) { $issues += "ERROR_META_TODAY_OR_FUTURE($($metaDt.ToString('yyyy-MM-dd')))" }
        }

        if (-not $fn) {
            $issues += 'WARN_NO_DATE_IN_FILENAME'
        }
        elseif ($metaDt -and ($fn.Date -ne $metaDt.Date)) {
            $src = if ($meta -and $meta.Source) { [string]$meta.Source } else { 'Unknown' }
            $issues += "WARN_FILENAME_DATE_MISMATCH(fn=$($fn.ToString('yyyy-MM-dd')) meta=$($metaDt.ToString('yyyy-MM-dd')) src=$src)"
        }

        $fsRecent = ($f.CreationTime.Date -ge $fsCutoff -or $f.LastWriteTime.Date -ge $fsCutoff)
        if ($fsRecent) { $issues += 'INFO_FILESYSTEM_RECENT' }

        $isError = [bool]($issues | Where-Object { $_ -like 'ERROR_*' } | Select-Object -First 1)
        $isWarn = [bool]($issues | Where-Object { $_ -like 'WARN_*' } | Select-Object -First 1)

        if ($isError) { $folderErrors++; $totErrors++ }
        if ($isWarn) { $folderWarns++; $totWarns++ }

        if ($isError) {
            if ($fn) { $fixable += $f.FullName } else { $manual += $f.FullName }
        }

        if ($issues.Count -gt 0) {
            $report += "- $($f.Name)"
            $report += "  - FileNameDate: $(if ($fn) { $fn.ToString('yyyy-MM-dd') } else { 'N/A' })"
            $report += "  - MetaDate: $(if ($metaDt) { $metaDt.ToString('yyyy-MM-dd') } else { 'N/A' })$(if ($meta -and $meta.Source) { \" [$($meta.Source)]\" } else { '' })"
            $report += "  - FS: C=$($f.CreationTime.ToString('yyyy-MM-dd')) W=$($f.LastWriteTime.ToString('yyyy-MM-dd'))"
            $report += "  - Issues: $($issues -join ', ')"
        }
    }

    $report += ""
    $report += "- Summary: Errors=$folderErrors  Warns=$folderWarns"

    if ($metaDates.Count -gt 0) {
        $sorted = $metaDates | Sort-Object
        $report += "- Meta range: $($sorted[0].ToString('yyyy-MM-dd')) -> $($sorted[-1].ToString('yyyy-MM-dd'))"
    }
    if ($fnDates.Count -gt 0) {
        $sorted = $fnDates | Sort-Object
        $report += "- Filename range: $($sorted[0].ToString('yyyy-MM-dd')) -> $($sorted[-1].ToString('yyyy-MM-dd'))"
    }
    $report += ""
}

$report = @($report)
$report += "## Totals"
$report += "- Gallery folders: $($galleryDirs.Count)"
$report += "- Media files (flat): $totFiles"
$report += "- Errors: $totErrors"
$report += "- Warns: $totWarns"
$report += ""

$fixable = $fixable | Sort-Object -Unique
$manual = $manual | Sort-Object -Unique

$report += "## Fix candidates"
$report += "- Fixable from filename (run Fix-DateFromFilename.ps1 on these): $($fixable.Count)"
$report += "- Needs manual decision (no filename date): $($manual.Count)"
$report += ""

if ($fixable.Count -gt 0) {
    $report += "### FixableFromFilename"
    foreach ($p in $fixable) { $report += "- $p" }
    $report += ""
}
if ($manual.Count -gt 0) {
    $report += "### NeedsManual"
    foreach ($p in $manual) { $report += "- $p" }
    $report += ""
}

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GALLERY DATES AUDIT" -ForegroundColor Cyan
Write-Host "Roots: $($RootPaths -join ', ')" -ForegroundColor Gray
Write-Host "Folders: $($galleryDirs.Count)  Files: $totFiles" -ForegroundColor White
Write-Host "Errors: $totErrors  Warns: $totWarns" -ForegroundColor White
Write-Host "Report: $reportPath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
