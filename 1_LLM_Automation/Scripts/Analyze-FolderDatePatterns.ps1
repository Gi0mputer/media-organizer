# ============================================================================
# Script Name: Analyze-FolderDatePatterns.ps1
# Project: Media Archive Management
# Purpose:
#   Analyze folder and file naming patterns to infer dates intelligently.
#   Handles patterns like:
#     - "Vacanza_Agosto_2024", "Estate2023" (month/season names)
#     - "20240815_Elba" (YYYYMMDD prefix)
#     - "2024/Evento" (year in path)
#   Reports files with date mismatches and suggests corrections.
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ScanPath,

    [int]$ReportTopN = 50,

    [switch]$WhatIf,
    [switch]$Execute
)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

$IsPreview = $WhatIf -or (-not $Execute)

# Month name mappings (Italian/English)
$MonthNames = @{
    'gennaio' = 1; 'january' = 1; 'jan' = 1; 'gen' = 1
    'febbraio' = 2; 'february' = 2; 'feb' = 2
    'marzo' = 3; 'march' = 3; 'mar' = 3
    'aprile' = 4; 'april' = 4; 'apr' = 4
    'maggio' = 5; 'may' = 5; 'mag' = 5
    'giugno' = 6; 'june' = 6; 'jun' = 6; 'giu' = 6
    'luglio' = 7; 'july' = 7; 'jul' = 7; 'lug' = 7
    'agosto' = 8; 'august' = 8; 'aug' = 8; 'ago' = 8
    'settembre' = 9; 'september' = 9; 'sep' = 9; 'set' = 9
    'ottobre' = 10; 'october' = 10; 'oct' = 10; 'ott' = 10
    'novembre' = 11; 'november' = 11; 'nov' = 11
    'dicembre' = 12; 'december' = 12; 'dec' = 12
}

# Season mappings (approximate)
$SeasonMonths = @{
    'inverno' = 1; 'winter' = 1
    'primavera' = 4; 'spring' = 4
    'estate' = 7; 'summer' = 7
    'autunno' = 10; 'fall' = 10; 'autumn' = 10
}

function Parse-YearFromName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    # Match 4-digit year (19xx or 20xx)
    if ($Name -match '(19\d{2}|20\d{2})') {
        return [int]$matches[1]
    }
    return $null
}

function Parse-MonthFromName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $lower = $Name.ToLower()
    
    # Try exact month name match
    foreach ($key in $MonthNames.Keys) {
        if ($lower -match "\b$key\b") {
            return $MonthNames[$key]
        }
    }
    
    # Try season match
    foreach ($key in $SeasonMonths.Keys) {
        if ($lower -match "\b$key\b") {
            return $SeasonMonths[$key]
        }
    }
    
    return $null
}

function Parse-DateFromName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    
    # YYYYMMDD or YYYY-MM-DD
    if ($Name -match '(19\d{2}|20\d{2})[-_]?(\d{2})[-_]?(\d{2})') {
        try {
            $y = [int]$matches[1]
            $m = [int]$matches[2]
            $d = [int]$matches[3]
            return Get-Date -Year $y -Month $m -Day $d -Hour 12 -Minute 0 -Second 0
        }
        catch { }
    }
    
    # Try year + month from text
    $year = Parse-YearFromName -Name $Name
    $month = Parse-MonthFromName -Name $Name
    
    if ($year -and $month) {
        # Use mid-month as default
        return Get-Date -Year $year -Month $month -Day 15 -Hour 12 -Minute 0 -Second 0
    }
    
    if ($year) {
        # Year only - use mid-year
        return Get-Date -Year $year -Month 7 -Day 1 -Hour 12 -Minute 0 -Second 0
    }
    
    return $null
}

function Get-BestMetadataDateTime {
    param([string]$FilePath)
    
    if (-not (Test-Path -LiteralPath $FilePath)) { return $null }
    
    $tagOrder = @('GPSDateTime', 'DateTimeOriginal', 'MediaCreateDate', 'TrackCreateDate', 'CreateDate')
    $args = @(
        '-s2',
        '-d', '%Y-%m-%d %H:%M:%S',
        '-GPSDateTime',
        '-DateTimeOriginal',
        '-MediaCreateDate',
        '-TrackCreateDate',
        '-CreateDate',
        $FilePath
    )
    
    try {
        $output = & exiftool @args 2>$null
        if (-not $output) { return $null }
        
        foreach ($tag in $tagOrder) {
            foreach ($line in $output) {
                if ($line -match "^$tag\s*:\s*(.+)$") {
                    $val = $matches[1].Trim()
                    if ($val -match '(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
                        try {
                            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) `
                                -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
                        }
                        catch { }
                    }
                }
            }
        }
    }
    catch { }
    
    return $null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FOLDER DATE PATTERN ANALYZER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Scan Path: $ScanPath"
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Host ""

if (-not (Test-Path -LiteralPath $ScanPath)) {
    Write-Fail "[ERROR] Path not found: $ScanPath"
    exit 1
}

# Get repository root
$repoRoot = $null
try {
    $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\')).Path.TrimEnd('\')
}
catch {
    $repoRoot = (Get-Location).Path.TrimEnd('\')
}

$analysisDir = Join-Path $repoRoot '1_LLM_Automation\Analysis'
New-Item -ItemType Directory -Path $analysisDir -Force | Out-Null

$reportPath = Join-Path $analysisDir ("FOLDER_DATE_PATTERNS_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))

Write-Info "[SCAN] Analyzing folders and files in $ScanPath ..."

$findings = @()
$totalFiles = 0
$totalFolders = 0

# Scan recursively
$allFolders = @(Get-ChildItem -LiteralPath $ScanPath -Directory -Recurse -ErrorAction SilentlyContinue)
$totalFolders = $allFolders.Count

Write-Info "[INFO] Found $totalFolders folders. Analyzing patterns..."

foreach ($folder in $allFolders) {
    # Skip service folders
    if ($folder.Name -in @('_mobile', 'Mobile', '_gallery', 'Gallery', '_trash', 'Trash', 'MERGE', 'RAW', 'Drive')) {
        continue
    }
    
    # Parse date from folder name
    $folderDate = Parse-DateFromName -Name $folder.Name
    if (-not $folderDate) {
        # Try parent folder path
        $parentPath = Split-Path -Path $folder.FullName -Parent
        if ($parentPath) {
            $parentName = Split-Path -Path $parentPath -Leaf
            $folderDate = Parse-DateFromName -Name $parentName
        }
    }
    
    if (-not $folderDate) { continue }
    
    # Get files in this folder (not recursive, just this level)
    $files = @(Get-ChildItem -LiteralPath $folder.FullName -File -ErrorAction SilentlyContinue | 
        Where-Object { $_.Extension -match '\.(jpg|jpeg|png|heic|mp4|mov|m4v|avi)$' })
    
    if ($files.Count -eq 0) { continue }
    
    $totalFiles += $files.Count
    
    # Sample up to 5 files for metadata check
    $sampleSize = [math]::Min(5, $files.Count)
    $samples = $files | Get-Random -Count $sampleSize
    
    $metaDates = @()
    foreach ($file in $samples) {
        $metaDate = Get-BestMetadataDateTime -FilePath $file.FullName
        if ($metaDate) {
            $metaDates += $metaDate.Date
        }
    }
    
    if ($metaDates.Count -eq 0) { continue }
    
    # Check if metadata dates are consistent with folder date
    $folderYear = $folderDate.Year
    $folderMonth = $folderDate.Month
    
    $mismatches = @()
    foreach ($md in $metaDates) {
        $yearDiff = [math]::Abs($md.Year - $folderYear)
        $monthDiff = [math]::Abs($md.Month - $folderMonth)
        
        if ($yearDiff -gt 0) {
            $mismatches += "Year mismatch: metadata=$($md.Year), folder=$folderYear"
        }
        elseif ($monthDiff -gt 2) {
            $mismatches += "Month mismatch: metadata=$($md.Month), folder=$folderMonth"
        }
    }
    
    if ($mismatches.Count -gt 0) {
        $findings += [pscustomobject]@{
            Folder        = $folder.FullName
            FolderDate    = $folderDate
            MetadataDates = $metaDates
            FileCount     = $files.Count
            Mismatches    = $mismatches
        }
    }
}

Write-Ok "[OK] Analysis complete. Found $($findings.Count) folders with date mismatches."
Write-Info "[INFO] Total folders scanned: $totalFolders"
Write-Info "[INFO] Total files analyzed: $totalFiles"

# Generate report
$report = @()
$report += "# Folder Date Pattern Analysis"
$report += ""
$report += "**Scan Path**: $ScanPath"
$report += "**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "**Mode**: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += ""
$report += "## Summary"
$report += "- Total folders scanned: $totalFolders"
$report += "- Total files analyzed: $totalFiles"
$report += "- Folders with date mismatches: $($findings.Count)"
$report += ""

if ($findings.Count -gt 0) {
    $report += "## Mismatches Found (Top $ReportTopN)"
    $report += ""
    
    $top = $findings | Select-Object -First $ReportTopN
    foreach ($f in $top) {
        $report += "### $($f.Folder)"
        $report += "- **Folder date inferred**: $($f.FolderDate.ToString('yyyy-MM-dd'))"
        $metaDatesStr = ($f.MetadataDates | ForEach-Object { $_.ToString('yyyy-MM-dd') } | Sort-Object | Select-Object -Unique) -join ', '
        $report += "- **Metadata dates (sample)**: $metaDatesStr"
        $report += "- **File count**: $($f.FileCount)"
        $report += "- **Issues**:"
        foreach ($m in $f.Mismatches) {
            $report += "  - $m"
        }
        $report += ""
    }
}
else {
    $report += "**No date mismatches found!** All folders appear to have consistent dates."
}

$report += ""
$report += "## Recommendations"
$report += ""
$report += "For folders with mismatches:"
$report += "1. Verify folder naming is correct (check travel/event dates)"
$report += "2. Use `Force-DateToMax.ps1` to fix metadata dates to match folder context"
$report += "3. Consider renaming folders if the name is misleading"
$report += ""

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Report saved: $reportPath" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
