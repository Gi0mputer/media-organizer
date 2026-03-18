# ============================================================================
# NOME: Import-iCloudPhotos-ToInbox.ps1
# DESCRIZIONE: Importa (copia) foto/video scaricati da iCloud Photos su Windows
#              in una cartella Inbox su SSD (E:\ per default), organizzando per
#              data EXIF/QuickTime quando possibile.
#
# NOTE:
# - Non modifica i file sorgenti (iCloud).
# - Non rinomina i file (Inbox = staging).
# - Crea un report in 3_Sync_Mobile_Drive/Logs (gitignored).
#
# USO (Preview default):
#   .\Import-iCloudPhotos-ToInbox.ps1
#   .\Import-iCloudPhotos-ToInbox.ps1 -IcloudPhotosRoot "C:\...\iCloud Photos\Photos"
#
# ESECUZIONE:
#   .\Import-iCloudPhotos-ToInbox.ps1 -Execute
#   .\Import-iCloudPhotos-ToInbox.ps1 -Execute -Yes
# ============================================================================

param(
    [string]$IcloudPhotosRoot = "",
    [string]$InboxRoot = "",

    [ValidateSet('None', 'Year', 'Month', 'Day')]
    [string]$Grouping = 'Month',

    [string[]]$ExcludeSubfolders = @('Uploads', 'Shared Albums'),

    [switch]$Execute,
    [switch]$Yes,
    [switch]$WhatIf,

    [int]$MaxFiles = 0
)

$ErrorActionPreference = 'SilentlyContinue'

$IsPreview = $WhatIf -or (-not $Execute)

$MEDIA_EXTENSIONS = @(
    '.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif',
    '.mp4', '.mov', '.m4v', '.avi', '.mkv', '.3gp'
)

$SKIP_EXTENSIONS = @('.aae', '.thm')

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Resolve-IcloudPhotosRoot {
    param([string]$Explicit)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path.TrimEnd('\')
    }

    $u = $env:USERPROFILE
    $candidates = @(
        (Join-Path $u 'Pictures\iCloud Photos\Photos'),
        (Join-Path $u 'Pictures\iCloud Photos\Downloads'),
        (Join-Path $u 'Pictures\iCloud Photos'),
        (Join-Path $u 'iCloud Photos\Photos'),
        (Join-Path $u 'iCloud Photos')
    )

    foreach ($c in $candidates) {
        try {
            if (Test-Path -LiteralPath $c) {
                return (Resolve-Path -LiteralPath $c).Path.TrimEnd('\')
            }
        } catch {}
    }

    return $null
}

function Resolve-InboxRoot {
    param([string]$Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit)) { return $Explicit.TrimEnd('\') }
    if (Test-Path -LiteralPath 'E:\') { return 'E:\_iphone_inbox' }
    return (Join-Path $env:USERPROFILE '_iphone_inbox')
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
        try { return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0 } catch { return $null }
    }

    if ($v -match '^(\d{4}):(\d{2}):(\d{2})') {
        try { return Get-Date -Year ([int]$matches[1]) -Month ([int]$matches[2]) -Day ([int]$matches[3]) -Hour 12 -Minute 0 -Second 0 } catch { return $null }
    }

    return $null
}

function Get-BestDateTimeForFile {
    param([System.IO.FileInfo]$FileItem)

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
        if ($dt) { return $dt }
    }

    return $null
}

function Get-GroupedFolder {
    param(
        [string]$Root,
        [string]$GroupingMode,
        [datetime]$Date
    )

    if (-not $Date) { return (Join-Path $Root '_UNKNOWN_DATE') }

    switch ($GroupingMode) {
        'None' { return $Root }
        'Year' { return (Join-Path $Root ($Date.ToString('yyyy'))) }
        'Month' { return (Join-Path (Join-Path $Root ($Date.ToString('yyyy'))) ($Date.ToString('yyyy-MM'))) }
        'Day' { return (Join-Path (Join-Path (Join-Path $Root ($Date.ToString('yyyy'))) ($Date.ToString('yyyy-MM'))) ($Date.ToString('yyyyMMdd'))) }
        default { return $Root }
    }
}

function Get-UniquePath {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $Path }

    $dir = Split-Path -Path $Path -Parent
    $base = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $ext = [System.IO.Path]::GetExtension($Path)

    for ($i = 1; $i -le 999; $i++) {
        $alt = Join-Path $dir ("{0}_DUP{1}{2}" -f $base, $i, $ext)
        if (-not (Test-Path -LiteralPath $alt)) { return $alt }
    }

    return $null
}

function Ensure-Directory {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path) { return }

    $toCreate = @()
    $p = $Path
    while (-not [string]::IsNullOrWhiteSpace($p) -and -not (Test-Path -LiteralPath $p)) {
        $toCreate += $p
        $parent = Split-Path -Path $p -Parent
        if ($parent -eq $p) { break }
        $p = $parent
    }

    [array]::Reverse($toCreate)
    foreach ($d in $toCreate) {
        try { New-Item -ItemType Directory -Path $d -Force | Out-Null } catch {}
    }
}

# Preconditions
$exiftool = Get-Command exiftool -ErrorAction SilentlyContinue
if (-not $exiftool) {
    Write-Fail "[ERROR] ExifTool not found in PATH."
    exit 1
}

$srcRoot = $null
try { $srcRoot = Resolve-IcloudPhotosRoot -Explicit $IcloudPhotosRoot } catch { $srcRoot = $null }
if (-not $srcRoot) {
    Write-Fail "[ERROR] iCloud Photos folder not found."
    Write-Host "Install/configura iCloud per Windows e abilita 'Foto', poi re-run con:" -ForegroundColor Yellow
    Write-Host "  -IcloudPhotosRoot \"C:\\...\\iCloud Photos\\Photos\"" -ForegroundColor Gray
    exit 1
}

$InboxRoot = Resolve-InboxRoot -Explicit $InboxRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IMPORT ICLOUD PHOTOS -> INBOX" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor Gray
Write-Host "Source: $srcRoot" -ForegroundColor Gray
Write-Host "Inbox:  $InboxRoot" -ForegroundColor Gray
Write-Host "Grouping: $Grouping" -ForegroundColor Gray
if ($MaxFiles -gt 0) { Write-Host "MaxFiles: $MaxFiles" -ForegroundColor Gray }
Write-Host ""

# Ensure Inbox root exists (execute only)
if (-not $IsPreview) {
    Ensure-Directory -Path $InboxRoot
}

# State
$stateDir = Join-Path $PSScriptRoot '.state'
try { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null } catch {}
$statePath = Join-Path $stateDir 'icloud_inbox_import_state.json'
$state = @{}
if (Test-Path -LiteralPath $statePath) {
    try {
        $raw = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) {
            $state[$p.Name] = $p.Value
        }
    } catch { $state = @{} }
}

# Report
$logDir = Join-Path $PSScriptRoot 'Logs'
try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch {}
$reportPath = Join-Path $logDir ("ICLOUD_IMPORT_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$report = @()
$report += "# iCloud Import Report"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += "Source: $srcRoot"
$report += "Inbox: $InboxRoot"
$report += "Grouping: $Grouping"
$report += ""

# Scan source
Write-Host "Scanning source..." -ForegroundColor Yellow
$all = Get-ChildItem -LiteralPath $srcRoot -Recurse -File -ErrorAction SilentlyContinue
$media = @()
$skippedPlaceholders = 0
foreach ($f in $all) {
    # Skip cloud placeholders (not fully downloaded)
    try {
        $attrs = $f.Attributes
        $isPlaceholder = (($attrs -band [System.IO.FileAttributes]::Offline) -ne 0) -or (($attrs -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
        if ($isPlaceholder) { $skippedPlaceholders++; continue }
    } catch {}

    $skipByFolder = $false
    foreach ($ex in $ExcludeSubfolders) {
        if ([string]::IsNullOrWhiteSpace($ex)) { continue }
        $pattern = "\\{0}\\" -f [regex]::Escape($ex)
        if ($f.FullName -match $pattern) { $skipByFolder = $true; break }
    }
    if ($skipByFolder) { continue }

    $ext = $f.Extension.ToLowerInvariant()
    if ($SKIP_EXTENSIONS -contains $ext) { continue }
    if ($MEDIA_EXTENSIONS -contains $ext) { $media += $f }
}

$media = $media | Sort-Object -Property FullName
if ($MaxFiles -gt 0 -and $media.Count -gt $MaxFiles) {
    $media = $media | Select-Object -First $MaxFiles
}

Write-Host "Media files found: $($media.Count)" -ForegroundColor Green
if ($skippedPlaceholders -gt 0) {
    Write-Warn "[WARN] Skipped placeholders (offline/reparse): $skippedPlaceholders (scarica i file iCloud in locale e riprova)"
}

if (-not $media -or $media.Count -eq 0) {
    $report += "No media files found."
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to import."
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 0
}

# Plan
$plan = @()
$skippedState = 0
foreach ($f in $media) {
    $sig = "{0}|{1}" -f $f.Length, $f.LastWriteTimeUtc.Ticks
    if ($state.ContainsKey($f.FullName) -and ($state[$f.FullName].sig -eq $sig)) {
        $skippedState++
        continue
    }

    $dt = Get-BestDateTimeForFile -FileItem $f
    $destFolder = Get-GroupedFolder -Root $InboxRoot -GroupingMode $Grouping -Date $dt
    $destPath = Join-Path $destFolder $f.Name

    $plan += [pscustomobject]@{
        Source = $f
        DateTime = $dt
        DestFolder = $destFolder
        DestPath = $destPath
        Sig = $sig
    }
}

Write-Host "To import: $($plan.Count)  (Skipped by state: $skippedState)" -ForegroundColor Cyan

if ($plan.Count -eq 0) {
    $report += "Nothing to import (all files already in state)."
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to import."
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 0
}

if (-not $IsPreview -and -not $Yes) {
    $ans = Read-Host "Type YES to import $($plan.Count) file(s) into Inbox"
    if ($ans -ne 'YES') {
        Write-Warn "Cancelled."
        exit 0
    }
}

# Execute plan
$importedOk = 0
$importedFail = 0
$unknownDate = 0

$report += "## Items"
foreach ($p in $plan) {
    $src = $p.Source
    $dt = $p.DateTime
    if (-not $dt) { $unknownDate++ }

    $folder = $p.DestFolder
    $dest = $p.DestPath

    if ($IsPreview) {
        Write-Info ("  [PREVIEW] {0} -> {1}" -f $src.FullName, $dest)
        $report += "- PREVIEW: $($src.FullName) -> $dest"
        continue
    }

    try {
        Ensure-Directory -Path $folder

        if (Test-Path -LiteralPath $dest) {
            # If same size, assume already imported; otherwise write dup
            $existing = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue
            if ($existing -and $existing.Length -eq $src.Length) {
                $state[$src.FullName] = @{ sig = $p.Sig; dest = $dest; importedAt = (Get-Date).ToString('s') }
                continue
            }

            $alt = Get-UniquePath -Path $dest
            if (-not $alt) { throw "Could not generate unique destination for $dest" }
            $dest = $alt
        }

        Copy-Item -LiteralPath $src.FullName -Destination $dest -Force
        $importedOk++

        # Save state for this file
        $state[$src.FullName] = @{ sig = $p.Sig; dest = $dest; importedAt = (Get-Date).ToString('s') }
        $report += "- OK: $($src.FullName) -> $dest"
    }
    catch {
        $importedFail++
        $report += "- FAIL: $($src.FullName) -> $dest"
    }
}

if (-not $IsPreview) {
    try {
        ($state | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $statePath -Encoding UTF8
    } catch {}
}

$report += ""
$report += "## Summary"
$report += "- Source scanned: $($media.Count)"
$report += "- Planned import: $($plan.Count)"
$report += "- Imported OK: $importedOk"
$report += "- Imported FAIL: $importedFail"
$report += "- Unknown EXIF date: $unknownDate"
$report += "- Skipped by state: $skippedState"
$report += "- Skipped placeholders (offline/reparse): $skippedPlaceholders"

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DONE" -ForegroundColor Cyan
Write-Host "Preview: $IsPreview" -ForegroundColor Gray
Write-Host "Imported: $importedOk OK, $importedFail FAIL" -ForegroundColor White
Write-Host "Unknown date: $unknownDate" -ForegroundColor Gray
Write-Host "Report: $reportPath" -ForegroundColor Gray
