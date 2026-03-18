# ============================================================================
# NOME: Publish-Gallery-ToiCloudUploads.ps1
# DESCRIZIONE: Pubblica il subset `_gallery` dal PC verso iCloud Photos (Uploads)
#              per farlo apparire su iPhone Photos.
#
# NOTE:
# - Copia i file (non sposta).
# - Per evitare upload inutili, mantiene uno state file in 3_Sync_Mobile_Drive/.state (gitignored).
# - Destinazione tipica: %USERPROFILE%\Pictures\iCloud Photos\Uploads
#
# USO (Preview default):
#   .\Publish-Gallery-ToiCloudUploads.ps1 "E:\2026\Evento"
#
# ESECUZIONE:
#   .\Publish-Gallery-ToiCloudUploads.ps1 "E:\2026\Evento" -Execute
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$SourcePaths,

    [string]$IcloudUploadsRoot = "",

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
$GALLERY_FOLDER_NAMES = @('_gallery', 'gallery')

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

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

function Sanitize-PathSegment {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return '_UNKNOWN' }
    $v = $Value
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($c in $invalid) { $v = $v.Replace($c, '_') }
    return $v.Trim()
}

function Resolve-IcloudUploadsRoot {
    param([string]$Explicit)

    if (-not [string]::IsNullOrWhiteSpace($Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path.TrimEnd('\')
    }

    $u = $env:USERPROFILE
    $candidates = @(
        (Join-Path $u 'Pictures\iCloud Photos\Uploads'),
        (Join-Path $u 'Pictures\iCloud Photos'),
        (Join-Path $u 'iCloud Photos\Uploads'),
        (Join-Path $u 'iCloud Photos')
    )

    foreach ($c in $candidates) {
        try {
            if (-not (Test-Path -LiteralPath $c)) { continue }

            if ((Split-Path -Path $c -Leaf).ToLowerInvariant() -eq 'uploads') {
                return (Resolve-Path -LiteralPath $c).Path.TrimEnd('\')
            }

            $u2 = Join-Path $c 'Uploads'
            if (Test-Path -LiteralPath $u2) {
                return (Resolve-Path -LiteralPath $u2).Path.TrimEnd('\')
            }
        } catch {}
    }

    return $null
}

function Is-InGalleryFolder {
    param([System.IO.FileInfo]$FileItem)
    $segs = ($FileItem.DirectoryName -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($s in $segs) {
        if ($GALLERY_FOLDER_NAMES -contains $s.ToLowerInvariant()) { return $true }
    }
    return $false
}

function Get-YearEventFromPath {
    param([string]$FullPath)
    $segs = ($FullPath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    for ($i = 0; $i -lt $segs.Count; $i++) {
        if ($segs[$i] -match '^(19\\d{2}|20\\d{2})$') {
            $year = $segs[$i]
            $event = if (($i + 1) -lt $segs.Count) { $segs[$i + 1] } else { '_NOEVENT' }
            return [pscustomobject]@{ Year = $year; Event = $event }
        }
    }
    return [pscustomobject]@{ Year = '_MISC'; Event = '_MISC' }
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

$uploadsRoot = $null
try { $uploadsRoot = Resolve-IcloudUploadsRoot -Explicit $IcloudUploadsRoot } catch { $uploadsRoot = $null }
if (-not $uploadsRoot) {
    Write-Fail "[ERROR] iCloud Uploads folder not found."
    Write-Host "Controlla che iCloud per Windows sia installato e che iCloud Photos sia abilitato (Uploads)." -ForegroundColor Yellow
    Write-Host "Oppure passa esplicitamente:" -ForegroundColor Yellow
    Write-Host "  -IcloudUploadsRoot \"C:\\...\\iCloud Photos\\Uploads\"" -ForegroundColor Gray
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PUBLISH _GALLERY -> ICLOUD PHOTOS (UPLOADS)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor Gray
Write-Host "Uploads: $uploadsRoot" -ForegroundColor Gray
Write-Host "Sources: $($SourcePaths -join ', ')" -ForegroundColor Gray
if ($MaxFiles -gt 0) { Write-Host "MaxFiles: $MaxFiles" -ForegroundColor Gray }
Write-Host ""

# State
$stateDir = Join-Path $PSScriptRoot '.state'
try { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null } catch {}
$statePath = Join-Path $stateDir 'icloud_upload_state.json'
$state = @{}
if (Test-Path -LiteralPath $statePath) {
    try {
        $raw = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        foreach ($p in $raw.PSObject.Properties) { $state[$p.Name] = $p.Value }
    } catch { $state = @{} }
}

# Report
$logDir = Join-Path $PSScriptRoot 'Logs'
try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch {}
$reportPath = Join-Path $logDir ("ICLOUD_PUBLISH_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$report = @()
$report += "# iCloud Publish Report (_gallery -> Uploads)"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += "Uploads: $uploadsRoot"
$report += "Sources: $($SourcePaths -join ', ')"
$report += ""

# Collect files
$files = @()
foreach ($p in $SourcePaths) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $rp = $null
    try { $rp = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path } catch { $rp = $null }
    if (-not $rp) { Write-Warn "[SKIP] Path not found: $p"; continue }

    $item = Get-Item -LiteralPath $rp -ErrorAction SilentlyContinue
    if (-not $item) { continue }

    if ($item.PSIsContainer) {
        $files += Get-ChildItem -LiteralPath $item.FullName -Recurse -File -ErrorAction SilentlyContinue
    }
    else {
        $files += $item
    }
}

$media = @()
foreach ($f in $files) {
    $ext = $f.Extension.ToLowerInvariant()
    if ($SKIP_EXTENSIONS -contains $ext) { continue }
    if (-not ($MEDIA_EXTENSIONS -contains $ext)) { continue }
    if (-not (Is-InGalleryFolder -FileItem $f)) { continue }
    $media += $f
}

$media = $media | Sort-Object -Property FullName -Unique
if ($MaxFiles -gt 0 -and $media.Count -gt $MaxFiles) { $media = $media | Select-Object -First $MaxFiles }

Write-Host "Gallery media files found: $($media.Count)" -ForegroundColor Green
if (-not $media -or $media.Count -eq 0) {
    $report += "No _gallery media found."
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to publish."
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

    $ye = Get-YearEventFromPath -FullPath $f.FullName
    $year = Sanitize-PathSegment -Value $ye.Year
    $event = Sanitize-PathSegment -Value $ye.Event

    $destFolder = Join-Path (Join-Path $uploadsRoot $year) $event
    $destPath = Join-Path $destFolder $f.Name

    $plan += [pscustomobject]@{
        Source = $f
        DestFolder = $destFolder
        DestPath = $destPath
        Sig = $sig
    }
}

Write-Host "To publish: $($plan.Count)  (Skipped by state: $skippedState)" -ForegroundColor Cyan
if ($plan.Count -eq 0) {
    $report += "Nothing to publish (all files already in state)."
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Ok "[OK] Nothing to publish."
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 0
}

if (-not $IsPreview -and -not $Yes) {
    $ans = Read-Host "Type YES to copy $($plan.Count) file(s) into iCloud Uploads"
    if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
}

$copiedOk = 0
$copiedFail = 0

$report += "## Items"
foreach ($p in $plan) {
    $src = $p.Source
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
            $existing = Get-Item -LiteralPath $dest -ErrorAction SilentlyContinue
            if ($existing -and $existing.Length -eq $src.Length) {
                $state[$src.FullName] = @{ sig = $p.Sig; dest = $dest; uploadedAt = (Get-Date).ToString('s') }
                continue
            }

            $alt = Get-UniquePath -Path $dest
            if (-not $alt) { throw "Could not generate unique destination for $dest" }
            $dest = $alt
        }

        Copy-Item -LiteralPath $src.FullName -Destination $dest -Force
        $copiedOk++
        $state[$src.FullName] = @{ sig = $p.Sig; dest = $dest; uploadedAt = (Get-Date).ToString('s') }
        $report += "- OK: $($src.FullName) -> $dest"
    }
    catch {
        $copiedFail++
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
$report += "- Gallery media scanned: $($media.Count)"
$report += "- Planned publish: $($plan.Count)"
$report += "- Copied OK: $copiedOk"
$report += "- Copied FAIL: $copiedFail"
$report += "- Skipped by state: $skippedState"

$report | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DONE" -ForegroundColor Cyan
Write-Host "Preview: $IsPreview" -ForegroundColor Gray
Write-Host "Copied: $copiedOk OK, $copiedFail FAIL" -ForegroundColor White
Write-Host "Report: $reportPath" -ForegroundColor Gray

