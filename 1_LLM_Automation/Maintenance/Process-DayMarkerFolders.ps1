# ============================================================================
# Script Name: Process-DayMarkerFolders.ps1
# Project: Media Archive Management
# Purpose:
#   Processes helper folders used during manual sorting:
#     - 1day\     -> all contents belong to ONE day (legacy alias: sameday\)
#                  Suffix is allowed to avoid name collisions: 1day_2\, 1day_3\, ...
#     - Nday\     -> contents belong to ~N days (e.g. 4day\) where N is an upper bound
#                  Suffix is allowed: 4day_2\, 4day_3\, ...
#
#   Workflow per marker folder:
#     1) Detect intended day/range from existing metadata/filename
#     2) Align metadata + filesystem timestamps (MAX strategy for anomalies)
#     3) Move contents OUT of the marker folder (same level)
#     4) Delete marker folder once empty
#
# Safety:
#   Default is PREVIEW. Use -Execute to apply.
#   Nday: outliers are clamped to end of detected range (MAX) or fallback range.
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$RootPaths,

    [switch]$WhatIf,
    [switch]$Execute,
    [switch]$Yes,

    [switch]$Force,

    [double]$MinClusterRatio = 0.7
)

$ErrorActionPreference = 'SilentlyContinue'

$IsPreview = $WhatIf -or (-not $Execute)

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp',
    '.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp'
)

$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.3gp')

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Get-RepoRoot {
    param([string]$Start)
    try { return (Resolve-Path -LiteralPath (Join-Path $Start '..\..')).Path.TrimEnd('\') } catch { return (Get-Location).Path.TrimEnd('\') }
}

function Get-ExpectedYearFromPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $p = $Path.TrimEnd('\')
    $segments = $p -split '\\'
    foreach ($seg in $segments) {
        if ($seg -match '^(19\d{2}|20\d{2})$') { return [int]$seg }
    }
    return $null
}

function Parse-DateTimeFromString {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()

    if ($v -match '^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
        } catch { return $null }
    }

    if ($v -match '^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
        } catch { return $null }
    }

    if ($v -match '^(\d{4})-(\d{2})-(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        } catch { return $null }
    }

    if ($v -match '^(\d{4}):(\d{2}):(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        } catch { return $null }
    }

    return $null
}

function Get-DateTimeFromFileName {
    param([string]$Name)

    $base = [System.IO.Path]::GetFileNameWithoutExtension($Name)

    # PXL_20250817_115315...
    if ($base -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})[_-](\d{2})(\d{2})(\d{2})') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour ([int]$matches[4]) -Minute ([int]$matches[5]) -Second ([int]$matches[6])
        } catch { return $null }
    }

    # YYYYMMDD_...
    if ($base -match '^(19\d{2}|20\d{2})(\d{2})(\d{2})_') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        } catch { return $null }
    }

    # Any YYYYMMDD in name
    if ($base -match '(?<!\d)(19\d{2}|20\d{2})(\d{2})(\d{2})(?!\d)') {
        try {
            return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0
        } catch { return $null }
    }

    return $null
}

function Get-BestDateTimeForFile {
    param([System.IO.FileInfo]$FileItem)

    $tagOrder = @('GPSDateTime', 'DateTimeOriginal', 'MediaCreateDate', 'TrackCreateDate', 'CreateDate', 'ModifyDate')
    $tagConfidence = @{
        'GPSDateTime'      = 3
        'DateTimeOriginal' = 3
        'MediaCreateDate'  = 2
        'TrackCreateDate'  = 2
        'CreateDate'       = 2
        'ModifyDate'       = 1
    }

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
        $FileItem.FullName
    )

    $lines = & exiftool @args 2>$null
    $map = @{}
    foreach ($line in $lines) {
        if ($line -match '^(\w+)\s*:\s*(.*)$') {
            $tag = $matches[1]
            $val = $matches[2].Trim()
            if (-not [string]::IsNullOrWhiteSpace($val)) { $map[$tag] = $val }
        }
    }

    foreach ($tag in $tagOrder) {
        if (-not $map.ContainsKey($tag)) { continue }
        $dt = Parse-DateTimeFromString -Value $map[$tag]
        if ($dt) {
            return [pscustomobject]@{
                DateTime   = $dt
                DateOnly   = $dt.Date
                Source     = $tag
                Confidence = $tagConfidence[$tag]
            }
        }
    }

    $fn = Get-DateTimeFromFileName -Name $FileItem.Name
    if ($fn) {
        return [pscustomobject]@{
            DateTime   = $fn
            DateOnly   = $fn.Date
            Source     = 'FileName'
            Confidence = 2
        }
    }

    $lw = $FileItem.LastWriteTime
    if ($lw.Year -ge 2001 -and $lw.Year -le ((Get-Date).Year + 1)) {
        $dt2 = Get-Date -Year $lw.Year -Month $lw.Month -Day $lw.Day -Hour $lw.Hour -Minute $lw.Minute -Second $lw.Second
        return [pscustomobject]@{
            DateTime   = $dt2
            DateOnly   = $dt2.Date
            Source     = 'LastWriteTime'
            Confidence = 1
        }
    }

    return $null
}

function Get-DayMarkerSpec {
    param([string]$FolderName)
    if ([string]::IsNullOrWhiteSpace($FolderName)) { return $null }
    if ($FolderName -match '^(?i)(1day|sameday)(?:_\d+)?$') {
        return [pscustomobject]@{ Kind = 'OneDay'; N = 1; Alias = ($FolderName -match '^(?i)sameday(?:_\d+)?$') }
    }
    if ($FolderName -match '^(?i)(\d+)day(?:_\d+)?$') {
        $n = [int]$matches[1]
        if ($n -le 1) { return [pscustomobject]@{ Kind = 'OneDay'; N = 1; Alias = $false } }
        return [pscustomobject]@{ Kind = 'NDay'; N = $n; Alias = $false }
    }
    return $null
}

function Find-DayMarkerFolders {
    param([string]$Root)

    $dirs = @()
    try {
        $rootItem = Get-Item -LiteralPath $Root -ErrorAction SilentlyContinue
        if ($rootItem -and $rootItem.PSIsContainer) {
            $spec = Get-DayMarkerSpec -FolderName $rootItem.Name
            if ($spec) { $dirs += $rootItem }
        }
    } catch {}

    $found = Get-ChildItem -LiteralPath $Root -Directory -Recurse -ErrorAction SilentlyContinue
    foreach ($d in $found) {
        if (Get-DayMarkerSpec -FolderName $d.Name) { $dirs += $d }
    }

    # IMPORTANT: marker folders repeat across the archive (many "1day", "3day", etc.).
    # Do NOT de-dup by object equality/Name; de-dup by FullName.
    return ($dirs | Sort-Object -Property FullName -Unique)
}

function Select-BestClusterWindow {
    param(
        [datetime[]]$Dates,
        [int]$AllowedSpanDays
    )

    if (-not $Dates -or $Dates.Count -eq 0) { return $null }
    $sorted = $Dates | Sort-Object
    if ($sorted.Count -eq 1) {
        return [pscustomobject]@{ Min = $sorted[0]; Max = $sorted[0]; Count = 1; Total = 1 }
    }

    $bestCount = 0
    $bestMin = $sorted[0]
    $bestMax = $sorted[0]
    $n = $sorted.Count

    for ($i = 0; $i -lt $n; $i++) {
        $j = $i
        while ($j -lt $n -and (($sorted[$j] - $sorted[$i]).TotalDays -le $AllowedSpanDays)) { $j++ }
        $count = $j - $i
        if ($count -gt $bestCount) {
            $bestCount = $count
            $bestMin = $sorted[$i]
            $bestMax = $sorted[$j - 1]
        }
    }

    return [pscustomobject]@{ Min = $bestMin; Max = $bestMax; Count = $bestCount; Total = $sorted.Count }
}

function Set-MediaFileDate {
    param(
        [string]$FilePath,
        [datetime]$TargetDateTime
    )

    $targetExif = $TargetDateTime.ToString('yyyy:MM:dd HH:mm:ss')
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()

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

    $exifArgs += $FilePath

    $exifOk = $true
    & exiftool @exifArgs > $null 2>&1
    if ($LASTEXITCODE -ne 0) { $exifOk = $false }

    $fsOk = $true
    try {
        $fi = Get-Item -LiteralPath $FilePath
        $fi.CreationTime = $TargetDateTime
        $fi.LastWriteTime = $TargetDateTime
    } catch { $fsOk = $false }

    if (-not $exifOk -and $fsOk) {
        Write-Warn "[WARN] ExifTool metadata write failed (timestamps fixed only): $FilePath"
    }

    return $fsOk
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PROCESS DAY MARKER FOLDERS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Host "RootPaths: $($RootPaths -join ', ')" -ForegroundColor Gray
Write-Host ""

$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Fail "[ERROR] ExifTool not found in PATH."
    exit 1
}

# Report
$repoRoot = Get-RepoRoot -Start $PSScriptRoot
$analysisDir = Join-Path $repoRoot '1_LLM_Automation\Analysis'
New-Item -ItemType Directory -Path $analysisDir -Force | Out-Null
$reportPath = Join-Path $analysisDir ("DAY_MARKERS_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$report = @()
$report += "# Day Marker Folders Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += "Force: $Force"
$report += "MinClusterRatio: $MinClusterRatio"
$report += ""
$report += "## Roots"
foreach ($r in $RootPaths) { $report += "- $r" }
$report += ""

$allMarkerFolders = @()
foreach ($root in $RootPaths) {
    if (-not (Test-Path -LiteralPath $root)) {
        Write-Warn "[SKIP] Root not found: $root"
        continue
    }
    $rp = (Resolve-Path -LiteralPath $root).Path.TrimEnd('\')
    $allMarkerFolders += Find-DayMarkerFolders -Root $rp
}
# IMPORTANT: Process deepest marker folders first to avoid moving/deleting a parent
# marker before its nested marker has been processed.
$allMarkerFolders = $allMarkerFolders |
Group-Object FullName | ForEach-Object { $_.Group | Select-Object -First 1 } |
Sort-Object -Property @{ Expression = { ([string]$_.FullName).TrimEnd('\').Length }; Descending = $true }, @{ Expression = 'FullName'; Descending = $false }

Write-Host "Marker folders found: $($allMarkerFolders.Count)" -ForegroundColor Cyan
$report += "## Marker folders found: $($allMarkerFolders.Count)"
foreach ($f in $allMarkerFolders) { $report += "- $($f.FullName)" }
$report += ""

if ($allMarkerFolders.Count -eq 0) {
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to do."
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 0
}

if (-not $IsPreview) {
    if (-not $Yes) {
        $ans = Read-Host "Type YES to process $($allMarkerFolders.Count) marker folder(s)"
        if ($ans -ne 'YES') {
            Write-Warn "Cancelled."
            exit 0
        }
    }
}

$processed = 0
$skipped = 0
$fixedOk = 0
$fixedFail = 0
$movedOk = 0
$movedConflict = 0
$movedFail = 0
$deletedFolders = 0

foreach ($folder in $allMarkerFolders) {
    $spec = Get-DayMarkerSpec -FolderName $folder.Name
    if (-not $spec) { continue }

    $processed++
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "[$processed/$($allMarkerFolders.Count)] $($folder.FullName)" -ForegroundColor Cyan
    Write-Host "Type: $($spec.Kind) (N=$($spec.N))" -ForegroundColor Gray
    if ($spec.Alias) { Write-Warn "[WARN] Folder tag 'sameday' is deprecated. Use '1day'." }

    $expectedYear = Get-ExpectedYearFromPath -Path $folder.FullName
    if ($expectedYear) { Write-Info "Expected year (from path): $expectedYear" }

    $filesAll = Get-ChildItem -LiteralPath $folder.FullName -File -Recurse -ErrorAction SilentlyContinue
    if (-not $filesAll -or $filesAll.Count -eq 0) {
        Write-Warn "[INFO] Folder is empty."
        $report += "### $($folder.FullName)"
        $report += "- Empty folder"
        $report += ""
        if (-not $IsPreview) {
            try { Remove-Item -LiteralPath $folder.FullName -Force -Recurse; $deletedFolders++ } catch {}
        }
        continue
    }

    $media = $filesAll | Where-Object { $MEDIA_EXTENSIONS -contains $_.Extension.ToLowerInvariant() }
    if (-not $media -or $media.Count -eq 0) {
        Write-Warn "[SKIP] No media files found inside."
        $skipped++
        $report += "### $($folder.FullName)"
        $report += "- Skipped: no media files"
        $report += ""
        continue
    }

    Write-Info "Media files: $($media.Count) (Total files: $($filesAll.Count))"

    $items = @()
    foreach ($m in $media) {
        $best = Get-BestDateTimeForFile -FileItem $m
        $items += [pscustomobject]@{
            File       = $m.FullName
            Name       = $m.Name
            Ext        = $m.Extension.ToLowerInvariant()
            Best       = $best
            DateOnly   = if ($best) { $best.DateOnly } else { $null }
            DateTime   = if ($best) { $best.DateTime } else { $null }
            Source     = if ($best) { $best.Source } else { 'Unknown' }
            Confidence = if ($best) { $best.Confidence } else { 0 }
        }
    }

    $dated = $items | Where-Object { $_.DateOnly -ne $null }
    if (-not $dated -or $dated.Count -eq 0) {
        Write-Warn "[SKIP] Cannot determine any reliable date in this folder."
        $skipped++
        $report += "### $($folder.FullName)"
        $report += "- Skipped: no usable dates detected"
        $report += ""
        continue
    }

    $datedForDetect = $dated
    if ($expectedYear) {
        $tmp = $datedForDetect | Where-Object { $_.DateOnly.Year -eq $expectedYear }
        if ($tmp -and $tmp.Count -gt 0) { $datedForDetect = $tmp }
    }

    $targetMin = $null
    $targetMax = $null
    $targetDay = $null

    if ($spec.Kind -eq 'OneDay') {
        $maxConf = ($datedForDetect | Measure-Object -Property Confidence -Maximum).Maximum
        $baseSet = $datedForDetect | Where-Object { $_.Confidence -eq $maxConf }

        $groups = $baseSet | Group-Object -Property DateOnly | ForEach-Object {
            $dt = ($_.Group | Select-Object -First 1).DateOnly
            [pscustomobject]@{
                Date  = $dt
                Count = $_.Count
                Score = ($_.Group | Measure-Object -Property Confidence -Sum).Sum
            }
        } | Where-Object { $_.Date } | Sort-Object @(
            @{ Expression = 'Score'; Descending = $true },
            @{ Expression = 'Count'; Descending = $true },
            @{ Expression = 'Date'; Descending = $false }
        )

        $targetDay = ($groups | Select-Object -First 1).Date
        if (-not $targetDay) { $targetDay = $datedForDetect[0].DateOnly }
        $targetMin = $targetDay.Date
        $targetMax = $targetDay.Date
        Write-Ok "Target day: $($targetDay.ToString('yyyy-MM-dd'))"
    }
    else {
        $allowedSpan = [math]::Max(0, ($spec.N - 1))

        $maxConf = ($datedForDetect | Measure-Object -Property Confidence -Maximum).Maximum
        $rangeSet = $datedForDetect | Where-Object { $_.Confidence -eq $maxConf }
        if (-not $rangeSet -or $rangeSet.Count -lt 2) {
            $rangeSet = $datedForDetect | Where-Object { $_.Confidence -ge ([math]::Max(1, ($maxConf - 1))) }
        }
        if (-not $rangeSet -or $rangeSet.Count -lt 2) { $rangeSet = $datedForDetect }

        $cluster = Select-BestClusterWindow -Dates ($rangeSet | ForEach-Object { $_.DateOnly }) -AllowedSpanDays $allowedSpan
        if (-not $cluster) {
            $cluster = $null
        }

        $rangeFromCluster = $false
        if ($cluster) {
            $ratio = if ($cluster.Total -gt 0) { [math]::Round(($cluster.Count / $cluster.Total), 3) } else { 0 }
            $spanDays = [int]([math]::Round(($cluster.Max - $cluster.Min).TotalDays))

            Write-Host "Detected range candidate: $($cluster.Min.ToString('yyyy-MM-dd')) -> $($cluster.Max.ToString('yyyy-MM-dd')) (span $spanDays day(s), coverage $ratio, N=$($spec.N))" -ForegroundColor Cyan

            if ($Force -or $ratio -ge $MinClusterRatio) {
                $targetMin = $cluster.Min.Date
                $targetMax = $cluster.Max.Date
                $rangeFromCluster = $true
            }
            else {
                Write-Warn "[WARN] Range detection uncertain (coverage $ratio < $MinClusterRatio). Falling back to N-day range."
            }
        }

        if (-not $rangeFromCluster) {
            $maxConf2 = ($datedForDetect | Measure-Object -Property Confidence -Maximum).Maximum
            $best = $datedForDetect | Where-Object { $_.Confidence -eq $maxConf2 } | Sort-Object -Property DateOnly | Select-Object -First 1
            $anchor = if ($best -and $best.DateOnly) { $best.DateOnly } else { ($datedForDetect | Sort-Object -Property DateOnly | Select-Object -First 1).DateOnly }

            if (-not $anchor) {
                Write-Warn "[SKIP] Cannot compute fallback range (no usable dates)."
                $skipped++
                $report += "### $($folder.FullName)"
                $report += "- Skipped: cannot compute range"
                $report += ""
                continue
            }

            $targetMin = $anchor.Date
            $targetMax = $anchor.Date.AddDays([math]::Max(0, ($spec.N - 1)))
            Write-Info "Fallback range: $($targetMin.ToString('yyyy-MM-dd')) -> $($targetMax.ToString('yyyy-MM-dd')) (N=$($spec.N))"
        }
    }

    # Apply metadata alignment
    $fixPlan = @()
    foreach ($it in $items) {
        $final = $null

        if ($spec.Kind -eq 'OneDay') {
            if ($it.DateTime) {
                $final = Get-Date -Year $targetMin.Year -Month $targetMin.Month -Day $targetMin.Day -Hour $it.DateTime.Hour -Minute $it.DateTime.Minute -Second $it.DateTime.Second
            }
            else {
                $final = Get-Date -Year $targetMin.Year -Month $targetMin.Month -Day $targetMin.Day -Hour 12 -Minute 0 -Second 0
            }
        }
        else {
            if (-not $it.DateOnly) {
                $final = $targetMax.AddHours(23).AddMinutes(59).AddSeconds(0)
            }
            elseif ($it.DateOnly -lt $targetMin -or $it.DateOnly -gt $targetMax) {
                $final = $targetMax.AddHours(23).AddMinutes(59).AddSeconds(0)
            }
            else {
                $final = $it.DateTime
                if (-not $final) { $final = $it.DateOnly.AddHours(12) }
            }
        }

        if ($final) {
            $fixPlan += [pscustomobject]@{ File = $it.File; Final = $final; Source = $it.Source }
        }
    }

    $report += "### $($folder.FullName)"
    $report += "- Kind: $($spec.Kind) (N=$($spec.N))"
    $report += "- Media files: $($media.Count)"
    if ($spec.Kind -eq 'OneDay') {
        $report += "- Target day: $($targetMin.ToString('yyyy-MM-dd'))"
    }
    else {
        $report += "- Detected range: $($targetMin.ToString('yyyy-MM-dd')) -> $($targetMax.ToString('yyyy-MM-dd'))"
    }
    $report += ""

    foreach ($fp in $fixPlan) {
        if ($IsPreview) {
            Write-Info "  [PREVIEW] Set $([System.IO.Path]::GetFileName($fp.File)) -> $($fp.Final.ToString('yyyy-MM-dd HH:mm:ss'))"
        }
        else {
            $ok = Set-MediaFileDate -FilePath $fp.File -TargetDateTime $fp.Final
            if ($ok) { $fixedOk++ } else { $fixedFail++ }
        }
    }

    # Move contents out (one-level): files and folders directly inside the marker folder.
    $parentDir = Split-Path -Path $folder.FullName -Parent
    $conflictDir = Join-Path $parentDir ("_CONFLICTS_FROM_{0}_{1}" -f $folder.Name, (Get-Date -Format 'yyyyMMdd_HHmmss'))

    $children = Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction SilentlyContinue
    $childFolders = @($children | Where-Object { $_.PSIsContainer })
    $childFiles = @($children | Where-Object { -not $_.PSIsContainer })

    # Move folders first (so _gallery becomes available in the parent), then files.
    foreach ($child in $childFolders) {
        $dest = Join-Path $parentDir $child.Name

        if ($IsPreview) {
            if (Test-Path -LiteralPath $dest) {
                Write-Warn "  [PREVIEW] MOVE conflict -> $conflictDir\\$($child.Name)"
                $movedConflict++
            }
            else {
                Write-Info "  [PREVIEW] MOVE -> $dest"
                $movedOk++
            }
            continue
        }

        try {
            if (Test-Path -LiteralPath $dest) {
                New-Item -ItemType Directory -Path $conflictDir -Force | Out-Null
                Move-Item -LiteralPath $child.FullName -Destination (Join-Path $conflictDir $child.Name) -Force
                $movedConflict++
            }
            else {
                Move-Item -LiteralPath $child.FullName -Destination $dest -Force
                $movedOk++
            }
        }
        catch {
            $movedFail++
        }
    }

    # If this marker is NOT inside a service folder, and the parent has a _gallery/Gallery folder,
    # move top-level media files into that gallery folder (to avoid leaving files at event root,
    # which would be missed by sync because only _gallery is considered for Gallery).
    $serviceNames = @('_mobile', 'mobile', '_gallery', 'gallery', '_trash', 'trash')
    $parentSegs = ($parentDir.TrimEnd('\') -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $isInsideServiceContext = $false
    foreach ($s in $parentSegs) {
        if ($serviceNames -contains $s.ToLowerInvariant()) { $isInsideServiceContext = $true; break }
    }

    $parentGalleryDir = $null
    $g1 = Join-Path $parentDir '_gallery'
    $g2 = Join-Path $parentDir 'Gallery'
    if (Test-Path -LiteralPath $g1) { $parentGalleryDir = $g1 }
    elseif (Test-Path -LiteralPath $g2) { $parentGalleryDir = $g2 }

    foreach ($child in $childFiles) {
        $dest = Join-Path $parentDir $child.Name
        $ext = [System.IO.Path]::GetExtension($child.Name).ToLowerInvariant()
        $shouldGoToGallery = (-not $isInsideServiceContext) -and $parentGalleryDir -and ($MEDIA_EXTENSIONS -contains $ext)
        if ($shouldGoToGallery) {
            $dest = Join-Path $parentGalleryDir $child.Name
        }

        if ($IsPreview) {
            if (Test-Path -LiteralPath $dest) {
                Write-Warn "  [PREVIEW] MOVE conflict -> $conflictDir\\$($child.Name)"
                $movedConflict++
            }
            else {
                Write-Info "  [PREVIEW] MOVE -> $dest"
                $movedOk++
            }
            continue
        }

        try {
            if (Test-Path -LiteralPath $dest) {
                New-Item -ItemType Directory -Path $conflictDir -Force | Out-Null
                Move-Item -LiteralPath $child.FullName -Destination (Join-Path $conflictDir $child.Name) -Force
                $movedConflict++
            }
            else {
                Move-Item -LiteralPath $child.FullName -Destination $dest -Force
                $movedOk++
            }
        }
        catch {
            $movedFail++
        }
    }

    # Cleanup: remove marker folder if empty
    if (-not $IsPreview) {
        try {
            $left = Get-ChildItem -LiteralPath $folder.FullName -Recurse -File -ErrorAction SilentlyContinue
            if (-not $left -or $left.Count -eq 0) {
                Remove-Item -LiteralPath $folder.FullName -Force -Recurse
                $deletedFolders++
            }
        } catch {}
    }
}

$report += "## Summary"
$report += "- Processed folders: $processed"
$report += "- Skipped folders: $skipped"
$report += "- Fixed (OK): $fixedOk"
$report += "- Fixed (FAIL): $fixedFail"
$report += "- Moved (OK): $movedOk"
$report += "- Moved (conflict): $movedConflict"
$report += "- Moved (FAIL): $movedFail"
$report += "- Deleted folders: $deletedFolders"
$report += ""

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DONE" -ForegroundColor Cyan
Write-Host "Preview: $IsPreview" -ForegroundColor Gray
Write-Host "Processed folders: $processed  Skipped: $skipped" -ForegroundColor White
Write-Host "Fixed: $fixedOk OK, $fixedFail FAIL" -ForegroundColor White
Write-Host "Moved: $movedOk OK, $movedConflict conflicts, $movedFail FAIL" -ForegroundColor White
Write-Host "Deleted marker folders: $deletedFolders" -ForegroundColor White
Write-Host "Report: $reportPath" -ForegroundColor Gray
