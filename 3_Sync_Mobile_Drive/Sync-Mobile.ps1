# ============================================================================
# Script Name: Sync-Mobile.ps1
# Project: Media Archive Management - Mobile Sync (Pixel 8)
# Purpose:
#   Sync "Mobile" subsets between PC (D:\ + E:\) and Pixel 8:
#     - PC2Phone        (destructive on phone)
#     - Phone2PC        (add-only)
#     - Phone2PCDelete  (destructive on PC)
#
# Notes:
#   - Phone path is accessed via Windows Shell (MTP): "PC\Pixel 8\...\SSD" (root-level folder)
#   - PC marker folders:
#       * "_gallery"/"Gallery"  -> dissolve into parent on phone (VISIBLE in Google Photos)
#       * "_mobile"/"Mobile"    -> becomes "...\Mobile\..." on phone (HIDDEN via .nomedia)
#   - Reverse mapping (Phone -> PC):
#       * If path contains "\Mobile\" -> map to "_mobile"
#       * Else -> map to "_gallery" (to keep mapping reversible)
# ============================================================================

param(
    [ValidateSet('PC2Phone', 'Phone2PC', 'Phone2PCDelete')]
    [string]$Mode = '',

    [ValidateSet('Both', 'Recent', 'Old')]
    [string]$SourceDisk = 'Both',

    [ValidateSet('Both', 'Mobile', 'Gallery', 'Ssd')]
    [string]$Sections = 'Both',

    [string]$ConfigPath = "$PSScriptRoot\\device_config.json",

    [string[]]$ScanRoots = @(),

    [switch]$WhatIf,
    [switch]$Execute,

    [switch]$Yes,

    [switch]$Force,

    [int]$MaxDeletes = 5000
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

$IsPreview = $WhatIf -or (-not $Execute)

$includeMobile = ($Sections -eq 'Both' -or $Sections -eq 'Mobile' -or $Sections -eq 'Ssd')
$includeGallery = ($Sections -eq 'Both' -or $Sections -eq 'Gallery')

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Fail "[ERROR] Config not found: $ConfigPath"
    exit 1
}

try { $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json } catch { $config = $null }
if (-not $config) {
    Write-Fail "[ERROR] Failed to parse config JSON: $ConfigPath"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($Mode)) {
    $Mode = $config.syncSettings.defaultMode
}

if ($Mode -notin @('PC2Phone', 'Phone2PC', 'Phone2PCDelete')) {
    Write-Fail "[ERROR] Invalid -Mode: $Mode"
    exit 1
}

$requireConfirmation = $true
if ($null -ne $config.syncSettings.requireConfirmation) {
    $requireConfirmation = [bool]$config.syncSettings.requireConfirmation
}

$singleDiskSafeMode = $true
if ($null -ne $config.syncSettings.singleDiskSafeMode) {
    $singleDiskSafeMode = [bool]$config.syncSettings.singleDiskSafeMode
}

$phoneBasePath = [string]$config.phone.basePath
if ([string]::IsNullOrWhiteSpace($phoneBasePath)) {
    Write-Fail "[ERROR] phone.basePath missing in config."
    exit 1
}

$SsdBaseId = 'SSD'
$MobileMarkerNames = @('Mobile', '_mobile')
$MobileMarkerCanonical = '_mobile'
$GalleryMarkerNames = @('Gallery', '_gallery')
$GalleryMarkerCanonical = '_gallery'
$TrashMarkerNames = @('Trash', '_trash')
$TrashMarkerCanonical = '_trash'
$GalleryExtensions = @('.jpg', '.jpeg', '.png', '.heic', '.gif', '.bmp', '.tiff', '.webp', '.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm', '.mpg', '.mpeg')

$PhoneMobileFolderName = 'Mobile'
$NomediaFileName = '.nomedia'

$MtpCopyMinTimeoutSeconds = 300
$MtpCopyMaxTimeoutSeconds = 7200
$MtpCopySecondsPerMB = 2
$MtpCopyPollMilliseconds = 1000

function Is-MarkerName {
    param(
        [string]$Name,
        [string[]]$Markers
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or (-not $Markers) -or $Markers.Count -eq 0) { return $false }
    foreach ($m in $Markers) {
        if ($Name -ieq $m) { return $true }
    }
    return $false
}

function Is-MobileMarkerName([string]$Name) { return (Is-MarkerName -Name $Name -Markers $MobileMarkerNames) }
function Is-GalleryMarkerName([string]$Name) { return (Is-MarkerName -Name $Name -Markers $GalleryMarkerNames) }
function Is-TrashMarkerName([string]$Name) { return (Is-MarkerName -Name $Name -Markers $TrashMarkerNames) }

function Get-ParentPhonePath([string]$BasePath) {
    if ([string]::IsNullOrWhiteSpace($BasePath)) { return $null }
    $p = $BasePath.Trim().TrimEnd('\')
    $idx = $p.LastIndexOf('\')
    if ($idx -lt 0) { return $null }
    return $p.Substring(0, $idx)
}

function New-PhoneKey([string]$BaseId, [string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($BaseId)) { return $null }
    $rel = if ($RelativePath) { $RelativePath.TrimStart('\') } else { '' }
    return "$BaseId::$rel"
}

function Split-PhoneKey([string]$Key) {
    if ([string]::IsNullOrWhiteSpace($Key)) { return $null }
    $parts = $Key -split '::', 2
    if ($parts.Count -lt 2) {
        return [pscustomobject]@{ BaseId = $SsdBaseId; RelativePath = $Key }
    }
    return [pscustomobject]@{ BaseId = $parts[0]; RelativePath = $parts[1] }
}

$legacyCameraPath = ''
if ($config.phone.legacyCameraPath) { $legacyCameraPath = [string]$config.phone.legacyCameraPath }
elseif ($config.phone.galleryBasePath) { $legacyCameraPath = [string]$config.phone.galleryBasePath } # backward compat

if ([string]::IsNullOrWhiteSpace($legacyCameraPath)) {
    # Derive storage root from basePath (handles both "...\\SSD" and legacy "...\\DCIM\\SSD")
    $storageRoot = Get-ParentPhonePath -BasePath $phoneBasePath
    if ($storageRoot) {
        $leaf = ($storageRoot -split '\\' | Select-Object -Last 1)
        if ($leaf -ieq 'DCIM') { $storageRoot = Get-ParentPhonePath -BasePath $storageRoot }
    }

    if ($storageRoot) { $legacyCameraPath = "$storageRoot\\DCIM\\Camera" }
}

$diskCandidates = @()
if ($config.disks.recent.path) { $diskCandidates += [string]$config.disks.recent.path }
if ($config.disks.old.path) { $diskCandidates += [string]$config.disks.old.path }
$diskCandidates = $diskCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

if ($diskCandidates.Count -eq 0) {
    Write-Fail "[ERROR] No disks configured."
    exit 1
}

function Normalize-Root([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $p = $Path.Trim()
    if ($p.Length -eq 2 -and $p[1] -eq ':') { $p += '\' }
    if (-not $p.EndsWith('\')) { $p += '\' }
    return $p
}

$diskCandidates = $diskCandidates | ForEach-Object { Normalize-Root $_ } | Where-Object { $_ } | Select-Object -Unique

function Get-ConnectedDisks([string[]]$Disks) {
    foreach ($d in $Disks) {
        if (Test-Path -LiteralPath $d) { $d }
    }
}

$connectedDisks = @(Get-ConnectedDisks -Disks $diskCandidates)
if ($connectedDisks.Count -eq 0) {
    Write-Fail "[ERROR] No configured disks are connected. Checked: $($diskCandidates -join ', ')"
    exit 1
}

$isSingleDisk = ($connectedDisks.Count -eq 1)

function Detect-RecentDisk([string[]]$Disks) {
    foreach ($d in $Disks) {
        if (Test-Path -LiteralPath (Join-Path $d '2024')) { return $d }
    }

    # Fallback: pick the disk with the highest year folder (20xx)
    $best = $null
    $bestYear = 0
    foreach ($d in $Disks) {
        $years = Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(19|20)\d{2}$' } |
        ForEach-Object { [int]$_.Name }
        if ($years) {
            $max = ($years | Measure-Object -Maximum).Maximum
            if ($max -gt $bestYear) { $bestYear = $max; $best = $d }
        }
    }
    return $best
}

function Detect-OldDisk([string[]]$Disks) {
    foreach ($d in $Disks) {
        if (Test-Path -LiteralPath (Join-Path $d '2019')) { return $d }
        if (Test-Path -LiteralPath (Join-Path $d '2018 e pre')) { return $d }
    }

    # Fallback: pick the disk with the lowest year folder (19xx/20xx)
    $best = $null
    $bestYear = 9999
    foreach ($d in $Disks) {
        $years = Get-ChildItem -LiteralPath $d -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(19|20)\d{2}$' } |
        ForEach-Object { [int]$_.Name }
        if ($years) {
            $min = ($years | Measure-Object -Minimum).Minimum
            if ($min -lt $bestYear) { $bestYear = $min; $best = $d }
        }
    }
    return $best
}

$recentDiskDetected = Detect-RecentDisk -Disks $connectedDisks
$oldDiskDetected = Detect-OldDisk -Disks $connectedDisks

$recentYearStart = 2024

function Is-YearName([string]$Name) { return ($Name -match '^(19\d{2}|20\d{2})$') }
function Get-YearValue([string]$Name) { if (Is-YearName $Name) { return [int]$Name } return $null }

function Resolve-DiskForPhoneRoot {
    param(
        [string]$RootName,
        [string[]]$ConnectedDisks
    )

    $year = Get-YearValue $RootName
    if ($year) {
        if ($year -ge $recentYearStart) {
            if (-not $recentDiskDetected) { return $null }
            if ($ConnectedDisks -contains $recentDiskDetected) { return $recentDiskDetected }
            return $null
        }
        else {
            if (-not $oldDiskDetected) { return $null }
            if ($ConnectedDisks -contains $oldDiskDetected) { return $oldDiskDetected }
            return $null
        }
    }

    # Theme root: choose existing folder on connected disks (prefer a single match)
    $hits = @()
    foreach ($d in $ConnectedDisks) {
        if (Test-Path -LiteralPath (Join-Path $d $RootName)) { $hits += $d }
    }

    if ($hits.Count -eq 1) { return $hits[0] }
    if ($hits.Count -gt 1) { return $hits[0] } # ambiguous, but proceed with first and warn upstream

    # If none exists, default to Recent if connected, else first connected
    if ($recentDiskDetected -and ($ConnectedDisks -contains $recentDiskDetected)) { return $recentDiskDetected }
    return $ConnectedDisks[0]
}

function Is-DiskAllowed([string]$DiskPath) {
    if ($SourceDisk -eq 'Both') { return $true }
    if ($SourceDisk -eq 'Recent') { return ($DiskPath -eq $recentDiskDetected) }
    if ($SourceDisk -eq 'Old') { return ($DiskPath -eq $oldDiskDetected) }
    return $true
}

function Get-ShellApp {
    if (-not $script:ShellApp) {
        $script:ShellApp = New-Object -ComObject Shell.Application
    }
    return $script:ShellApp
}

function Get-ShellFolderFromSegments {
    param([string[]]$Segments)

    $shell = Get-ShellApp
    $current = $shell.Namespace(0x11) # This PC

    foreach ($seg in $Segments) {
        if ([string]::IsNullOrWhiteSpace($seg)) { continue }

        $match = $null
        foreach ($it in $current.Items()) {
            if ($it.Name -ieq $seg) { $match = $it; break }
        }

        if (-not $match) {
            $avail = @()
            foreach ($it in $current.Items()) { $avail += $it.Name }
            throw "Segment not found: '$seg'. Available under '$($current.Self.Name)': $($avail -join ', ')"
        }

        $current = $shell.Namespace($match)
        if (-not $current) { throw "Cannot open shell folder for segment '$seg'." }
    }

    return $current
}

function Get-PhoneBaseFolder {
    param([string]$BasePath)

    $segments = ($BasePath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($segments.Count -gt 0 -and ($segments[0] -ieq 'PC' -or $segments[0] -ieq 'Questo PC' -or $segments[0] -ieq 'This PC')) {
        $segments = $segments | Select-Object -Skip 1
    }

    return Get-ShellFolderFromSegments -Segments $segments
}

function Get-MtpChildFolder {
    param($ParentFolder, [string]$Name)
    foreach ($it in $ParentFolder.Items()) {
        if ($it.IsFolder -and $it.Name -ieq $Name) {
            return (Get-ShellApp).Namespace($it)
        }
    }
    return $null
}

function Ensure-MtpFolder {
    param(
        $BaseFolder,
        [string]$RelativeDir
    )

    $folder = $BaseFolder
    $parts = ($RelativeDir -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($p in $parts) {
        $next = Get-MtpChildFolder -ParentFolder $folder -Name $p
        if (-not $next) {
            try { $null = $folder.NewFolder($p) } catch {}

            $tries = 0
            while (-not $next -and $tries -lt 10) {
                Start-Sleep -Milliseconds 300
                $next = Get-MtpChildFolder -ParentFolder $folder -Name $p
                $tries++
            }
        }

        if (-not $next) {
            throw "Failed to create/find phone folder: $p under $($folder.Self.Name)"
        }
        $folder = $next
    }

    return $folder
}

function Get-MtpFilesRecursive {
    param(
        $Folder,
        [string]$RelativePrefix = ''
    )

    $results = @()
    foreach ($it in $Folder.Items()) {
        if ($it.IsFolder) {
            $sub = (Get-ShellApp).Namespace($it)
            if ($sub) {
                $nextPrefix = if ([string]::IsNullOrEmpty($RelativePrefix)) { $it.Name } else { "$RelativePrefix\$($it.Name)" }
                $results += Get-MtpFilesRecursive -Folder $sub -RelativePrefix $nextPrefix
            }
            continue
        }

        # IMPORTANT: On MTP, $it.Name is often the display name without extension.
        # Use System.FileName to keep extensions and make PC<->Phone matching reliable.
        $fileName = $null
        try { $fileName = [string](Try-GetMtpExtendedProperty -Item $it -Key 'System.FileName') } catch { $fileName = $null }
        if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = [string]$it.Name }

        $rel = if ([string]::IsNullOrEmpty($RelativePrefix)) { $fileName } else { "$RelativePrefix\$fileName" }
        $results += [pscustomobject]@{
            RelativePath = $rel
            Name         = $fileName
            Item         = $it
        }
    }
    return $results
}

function Get-MtpFilesOneLevel {
    param($Folder)

    $results = @()
    foreach ($it in $Folder.Items()) {
        if ($it.IsFolder) { continue }
        $fileName = $null
        try { $fileName = [string](Try-GetMtpExtendedProperty -Item $it -Key 'System.FileName') } catch { $fileName = $null }
        if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = [string]$it.Name }
        $results += [pscustomobject]@{
            RelativePath = $fileName
            Name         = $fileName
            Item         = $it
        }
    }
    return $results
}

function Find-MtpItemByName {
    param($Folder, [string]$Name)
    if (-not $Folder -or [string]::IsNullOrWhiteSpace($Name)) { return $null }
    try {
        $parsed = $Folder.ParseName($Name)
        if ($parsed -and (-not $parsed.IsFolder)) { return $parsed }
    } catch {}
    try {
        foreach ($it in $Folder.Items()) {
            if ($it.IsFolder) { continue }
            try {
                $full = [string](Try-GetMtpExtendedProperty -Item $it -Key 'System.FileName')
                if ($full -and ($full -ieq $Name)) { return $it }
            } catch {}
            if ($it.Name -ieq $Name) { return $it }
        }
    } catch {}
    return $null
}

function Remove-MtpFile {
    param(
        $ParentFolder,
        [string]$FileName
    )

    $it = Find-MtpItemByName -Folder $ParentFolder -Name $FileName
    if (-not $it) { return $false }
    try {
        $it.InvokeVerb('Delete')
        return $true
    }
    catch {
        return $false
    }
}

function Get-MtpCopyTimeoutSeconds {
    param([int64]$SizeBytes)

    if (-not $SizeBytes -or $SizeBytes -le 0) { return $MtpCopyMinTimeoutSeconds }
    $mb = [math]::Ceiling($SizeBytes / 1MB)
    $calc = [int]([math]::Ceiling(($mb * $MtpCopySecondsPerMB) + 60))
    return [int]([math]::Min($MtpCopyMaxTimeoutSeconds, [math]::Max($MtpCopyMinTimeoutSeconds, $calc)))
}

function Copy-PCFileToMtp {
    param(
        [string]$SourcePath,
        [int64]$SourceSizeBytes = 0,
        $DestFolder
    )

    $fileName = Split-Path -Path $SourcePath -Leaf
    $DestFolder.CopyHere($SourcePath, 16) | Out-Null # 16 = no confirmation

    $timeoutSeconds = Get-MtpCopyTimeoutSeconds -SizeBytes $SourceSizeBytes
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    $lastStatus = Get-Date

    while ((Get-Date) -lt $deadline) {
        $it = Find-MtpItemByName -Folder $DestFolder -Name $fileName
        if ($it) { return $true }

        if (((Get-Date) - $lastStatus).TotalSeconds -ge 30) {
            $elapsed = [int]([math]::Round(($timeoutSeconds - ($deadline - (Get-Date)).TotalSeconds)))
            if ($elapsed -lt 0) { $elapsed = 0 }
            Write-Info "  ...waiting for MTP copy to finish ($elapsed sec elapsed, timeout $timeoutSeconds sec)"
            $lastStatus = Get-Date
        }

        Start-Sleep -Milliseconds $MtpCopyPollMilliseconds
    }
    return $false
}

function Copy-MtpItemToPC {
    param(
        $MtpItem,
        [string]$DestDir,
        [int64]$ExpectedSizeBytes = 0
    )

    $shell = Get-ShellApp
    $destFolder = $shell.Namespace($DestDir)
    if (-not $destFolder) { throw "Cannot open destination folder: $DestDir" }

    $destFolder.CopyHere($MtpItem, 16) | Out-Null

    # IMPORTANT: On MTP, .Name can be a display name without extension. Use System.FileName when possible.
    $fileName = $null
    try { $fileName = [string](Try-GetMtpExtendedProperty -Item $MtpItem -Key 'System.FileName') } catch { $fileName = $null }
    if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = [string]$MtpItem.Name }

    $destPath = Join-Path $DestDir $fileName

    $timeoutSeconds = Get-MtpCopyTimeoutSeconds -SizeBytes $ExpectedSizeBytes
    $deadline = (Get-Date).AddSeconds($timeoutSeconds)
    $lastStatus = Get-Date
    $lastLen = -1
    $stableCount = 0

    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $destPath) {
            $len = $null
            try { $len = (Get-Item -LiteralPath $destPath -ErrorAction SilentlyContinue).Length } catch { $len = $null }

            if ($ExpectedSizeBytes -gt 0 -and $len -ge $ExpectedSizeBytes) { return $true }

            if ($ExpectedSizeBytes -le 0 -and $len -and $len -gt 0) {
                if ($len -eq $lastLen) { $stableCount++ } else { $stableCount = 0 }
                if ($stableCount -ge 6) { return $true } # ~3s stable (6 * 500ms)
                $lastLen = $len
            }
        }

        if (((Get-Date) - $lastStatus).TotalSeconds -ge 30) {
            $elapsed = [int]([math]::Round(($timeoutSeconds - ($deadline - (Get-Date)).TotalSeconds)))
            if ($elapsed -lt 0) { $elapsed = 0 }
            $sizeLabel = if ($ExpectedSizeBytes -gt 0) { ("{0} MB" -f ([math]::Round($ExpectedSizeBytes / 1MB, 1))) } else { "unknown size" }
            Write-Info "  ...waiting for MTP copy to finish ($elapsed sec elapsed, timeout $timeoutSeconds sec, $sizeLabel)"
            $lastStatus = Get-Date
        }

        Start-Sleep -Milliseconds 500
    }

    return $false
}

function Map-PcPathSegmentsToPhone([string[]]$Segments) {
    $hasGallery = $false
    foreach ($s in $Segments) {
        if (Is-GalleryMarkerName $s) { $hasGallery = $true; break }
    }

    $out = @()
    foreach ($s in $Segments) {
        if ([string]::IsNullOrWhiteSpace($s)) { continue }
        if ($s -match '^[\\/]+$') { continue }
        if (Is-TrashMarkerName $s) { continue }
        if (Is-GalleryMarkerName $s) { continue } # dissolve _gallery/Gallery into parent on phone
        if (Is-MobileMarkerName $s) {
            # Gallery marker wins: if a Gallery folder exists anywhere in the path, do NOT nest under Mobile.
            if ($hasGallery) { continue }
            $out += $PhoneMobileFolderName
            continue
        } # _mobile -> Mobile on phone
        $out += $s
    }
    return $out
}

function Get-PhoneRelativeFromPcPath {
    param(
        [string]$DiskRoot,
        [string]$PcPath
    )

    $root = Normalize-Root $DiskRoot
    $full = (Resolve-Path -LiteralPath $PcPath).Path
    $rel = $full.Substring($root.Length).TrimStart('\')
    $segs = $rel -split '\\'
    $mapped = Map-PcPathSegmentsToPhone -Segments $segs
    return ($mapped -join '\')
}

function Get-PcPathFromPhoneRelative {
    param(
        [string]$DiskRoot,
        [string]$PhoneRelative
    )

    $rel = $PhoneRelative.TrimStart('\')
    $segs = $rel -split '\\'
    if ($segs.Count -lt 1) { return $null }

    $fileName = $segs[-1]
    $dirSegs = if ($segs.Count -gt 1) { $segs[0..($segs.Count - 2)] } else { @() }

    $mobileIndex = -1
    for ($i = 0; $i -lt $dirSegs.Count; $i++) {
        if ($dirSegs[$i] -ieq $PhoneMobileFolderName) { $mobileIndex = $i; break }
    }

    $newDirSegs = @()
    if ($mobileIndex -ge 0) {
        for ($i = 0; $i -lt $dirSegs.Count; $i++) {
            if ($i -eq $mobileIndex) { $newDirSegs += $MobileMarkerCanonical }
            else { $newDirSegs += $dirSegs[$i] }
        }
    }
    else {
        $newDirSegs = @($dirSegs + $GalleryMarkerCanonical)
    }

    $destDir = Join-Path $DiskRoot ($newDirSegs -join '\')
    return (Join-Path $destDir $fileName)
}

function Delete-ToRecycleBin([string]$Path) {
    try { Add-Type -AssemblyName Microsoft.VisualBasic | Out-Null } catch {}
    try {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
            [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing
        )
        return $true
    }
    catch {
        return $false
    }
}

function Load-Snapshot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

function Save-Snapshot([string]$Path, $Obj) {
    $json = $Obj | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $Path -Encoding UTF8
}

function Ensure-Hashtable($Value) {
    if ($null -eq $Value) { return @{} }
    if ($Value -is [hashtable]) { return $Value }
    $ht = @{}
    foreach ($p in $Value.PSObject.Properties) {
        $ht[$p.Name] = $p.Value
    }
    return $ht
}

$stateDir = Join-Path $PSScriptRoot '.state'
$logDir = Join-Path $PSScriptRoot 'Logs'
New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
New-Item -Path $logDir -ItemType Directory -Force | Out-Null

# Template file used to create ".nomedia" on the phone via MTP copy.
$nomediaTemplatePath = Join-Path $stateDir $NomediaFileName
if (-not (Test-Path -LiteralPath $nomediaTemplatePath)) {
    try { New-Item -Path $nomediaTemplatePath -ItemType File -Force | Out-Null } catch {}
}

$runId = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $logDir "SYNC_MOBILE_${Mode}_${runId}.log"

function Log([string]$Line) {
    $ts = Get-Date -Format 'HH:mm:ss'
    "$ts  $Line" | Out-File -FilePath $logPath -Encoding UTF8 -Append
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SYNC MOBILE (Pixel 8) - $Mode" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Config: $ConfigPath"
Write-Host "PhoneBase (SSD): $phoneBasePath"
Write-Host "LegacyCameraPath (cleanup only): $legacyCameraPath" -ForegroundColor Gray
Write-Host "Disks (connected): $($connectedDisks -join ', ')"
Write-Host "Detected recent disk (>= $recentYearStart): $(if ($recentDiskDetected) { $recentDiskDetected } else { 'N/A' })" -ForegroundColor Gray
Write-Host "Detected old disk (<  $recentYearStart): $(if ($oldDiskDetected) { $oldDiskDetected } else { 'N/A' })" -ForegroundColor Gray
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Host "SourceDisk filter: $SourceDisk"
Write-Host "Sections: $Sections" -ForegroundColor Gray
if ($ScanRoots -and $ScanRoots.Count -gt 0) { Write-Host "ScanRoots: $($ScanRoots -join ', ')" -ForegroundColor Gray }
if ($isSingleDisk) { Write-Warn "[WARN] Single-disk detected: $($connectedDisks[0])" }
Write-Host ""

Log "START Mode=$Mode Preview=$IsPreview SourceDisk=$SourceDisk"
Log "Sections=$Sections"
Log "PhoneBase(SSD)=$phoneBasePath"
Log "LegacyCameraPath=$legacyCameraPath"
Log "ConnectedDisks=$($connectedDisks -join ', ')"
if ($config.disks.recent.path -and $recentDiskDetected -and (Normalize-Root $config.disks.recent.path) -ne $recentDiskDetected) {
    Write-Warn "[WARN] Config recent disk ($($config.disks.recent.path)) differs from detected ($recentDiskDetected)."
}
if ($config.disks.old.path -and $oldDiskDetected -and (Normalize-Root $config.disks.old.path) -ne $oldDiskDetected) {
    Write-Warn "[WARN] Config old disk ($($config.disks.old.path)) differs from detected ($oldDiskDetected)."
}

# Connect to phone base folder (MTP)
$phoneBaseFolder = $null
if ($includeMobile -or $includeGallery) {
    $tries = 0
    $lastErr = $null
    while (-not $phoneBaseFolder -and $tries -lt 8) {
        try {
            $phoneBaseFolder = Get-PhoneBaseFolder -BasePath $phoneBasePath
            $lastErr = $null
        }
        catch {
            $phoneBaseFolder = $null
            try { $lastErr = $_.Exception.Message } catch { $lastErr = $null }
        }

        if (-not $phoneBaseFolder) { Start-Sleep -Milliseconds 800 }
        $tries++
    }
    if (-not $phoneBaseFolder) {
        Write-Fail "[ERROR] Cannot access phone base path via Shell: $phoneBasePath"
        Write-Warn "Ensure Pixel 8 is connected and unlocked, and SSD exists."
        if ($lastErr) { Write-Warn "Last error: $lastErr" }
        exit 1
    }
    Write-Ok "[OK] Phone path reachable: $phoneBasePath"
}

function Try-GetMtpExtendedProperty {
    param(
        $Item,
        [string]$Key
    )

    if (-not $Item -or [string]::IsNullOrWhiteSpace($Key)) { return $null }
    try { return $Item.ExtendedProperty($Key) } catch { return $null }
}

function Try-GetMtpItemSizeBytes {
    param($Item)
    $v = Try-GetMtpExtendedProperty -Item $Item -Key 'System.Size'
    if ($null -eq $v) { return $null }
    try { return [int64]$v } catch {}
    try {
        $s = [string]$v
        if ($s -match '^\d+$') { return [int64]$s }
    } catch {}
    return $null
}

function Try-GetMtpItemDateModified {
    param($Item)
    $v = Try-GetMtpExtendedProperty -Item $Item -Key 'System.DateModified'
    if ($null -eq $v) { return $null }
    if ($v -is [datetime]) { return [datetime]$v }
    try { return [datetime]::Parse([string]$v) } catch { return $null }
}

function Build-PcMobileSelection {
    param(
        [string[]]$Disks,
        [string[]]$ScanRoots,
        [switch]$IncludeMobile,
        [switch]$IncludeGallery
    )

    $items = @()

    # ---- MOBILE (_mobile -> Mobile\...) ----
    if ($IncludeMobile) {
        $mobileDirs = @()
        foreach ($d in $Disks) {
            if (-not (Is-DiskAllowed $d)) { continue }

            $rootsToScan = @()
            if ($ScanRoots -and $ScanRoots.Count -gt 0) {
                foreach ($sr in $ScanRoots) {
                    if (-not $sr) { continue }
                    if (-not (Test-Path -LiteralPath $sr)) { continue }
                    $rp = (Resolve-Path -LiteralPath $sr).Path.TrimEnd('\')
                    if ($rp.StartsWith($d, [System.StringComparison]::OrdinalIgnoreCase)) { $rootsToScan += $rp }
                }
            }
            else {
                $rootsToScan = @($d.TrimEnd('\') + '\')
            }

            foreach ($root in ($rootsToScan | Select-Object -Unique)) {
                Write-Info "[SCAN] Searching _mobile folders in $root ..."
                try {
                    $rootItem = Get-Item -LiteralPath $root -ErrorAction SilentlyContinue
                    if ($rootItem -and $rootItem.PSIsContainer -and (Is-MobileMarkerName $rootItem.Name)) { $mobileDirs += $rootItem }
                } catch {}

                foreach ($marker in $MobileMarkerNames) {
                    $found = Get-ChildItem -LiteralPath $root -Directory -Recurse -Filter $marker -ErrorAction SilentlyContinue
                    if ($found) { $mobileDirs += ($found | Where-Object { Is-MobileMarkerName $_.Name }) }
                }
            }
        }

        $mobileDirs = $mobileDirs | Sort-Object FullName -Unique

        foreach ($dir in $mobileDirs) {
            $dirSegs = ($dir.FullName -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if ($dirSegs | Where-Object { Is-TrashMarkerName $_ } | Select-Object -First 1) { continue }

            # Ensure .nomedia exists in every _mobile folder (one-time + enforced going forward)
            $nomediaPc = Join-Path $dir.FullName $NomediaFileName
            if (-not (Test-Path -LiteralPath $nomediaPc)) {
                if ($IsPreview) {
                    Write-Warn "[WARN] Missing $NomediaFileName in PC mobile folder: $($dir.FullName)"
                }
                else {
                    try { New-Item -Path $nomediaPc -ItemType File -Force | Out-Null } catch {}
                }
            }

            $disk = $Disks | Where-Object { $dir.FullName.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $disk) { continue }

            $files = Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $relToMobile = $f.FullName.Substring($dir.FullName.Length).TrimStart('\')
                $segments = ($relToMobile -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

                # Never sync files inside Trash markers.
                if ($segments | Where-Object { Is-TrashMarkerName $_ } | Select-Object -First 1) { continue }

                # If a file lives under a Gallery segment inside _mobile, do not sync it from Mobile.
                # It will be picked up only if it is directly inside a Gallery/_gallery folder.
                if ($segments | Where-Object { Is-GalleryMarkerName $_ } | Select-Object -First 1) { continue }

                $relPhone = Get-PhoneRelativeFromPcPath -DiskRoot $disk -PcPath $f.FullName
                if ([string]::IsNullOrWhiteSpace($relPhone)) { continue }

                $phoneKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $relPhone
                if ([string]::IsNullOrWhiteSpace($phoneKey)) { continue }

                $items += [pscustomobject]@{
                    DiskRoot      = $disk
                    PcPath        = $f.FullName
                    PhoneKey      = $phoneKey
                    PhoneBaseId   = $SsdBaseId
                    PhoneRelative = $relPhone
                    Size          = $f.Length
                    LastWriteUtc  = $f.LastWriteTimeUtc.ToString('o')
                }
            }
        }
    }

    # ---- GALLERY (_gallery dissolves into parent; phone shows it normally) ----
    if ($IncludeGallery) {
        $galleryDirs = @()
        foreach ($d in $Disks) {
            if (-not (Is-DiskAllowed $d)) { continue }

            $rootsToScan = @()
            if ($ScanRoots -and $ScanRoots.Count -gt 0) {
                foreach ($sr in $ScanRoots) {
                    if (-not $sr) { continue }
                    if (-not (Test-Path -LiteralPath $sr)) { continue }
                    $rp = (Resolve-Path -LiteralPath $sr).Path.TrimEnd('\')
                    if ($rp.StartsWith($d, [System.StringComparison]::OrdinalIgnoreCase)) { $rootsToScan += $rp }
                }
            }
            else {
                $rootsToScan = @($d.TrimEnd('\') + '\')
            }

            foreach ($root in ($rootsToScan | Select-Object -Unique)) {
                Write-Info "[SCAN] Searching _gallery folders in $root ..."
                try {
                    $rootItem = Get-Item -LiteralPath $root -ErrorAction SilentlyContinue
                    if ($rootItem -and $rootItem.PSIsContainer -and (Is-GalleryMarkerName $rootItem.Name)) { $galleryDirs += $rootItem }
                } catch {}

                foreach ($marker in $GalleryMarkerNames) {
                    $found = Get-ChildItem -LiteralPath $root -Directory -Recurse -Filter $marker -ErrorAction SilentlyContinue
                    if ($found) { $galleryDirs += ($found | Where-Object { Is-GalleryMarkerName $_.Name }) }
                }
            }
        }

        $galleryDirs = $galleryDirs | Sort-Object FullName -Unique

        foreach ($gd in $galleryDirs) {
            $gdSegs = ($gd.FullName -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            if ($gdSegs | Where-Object { Is-TrashMarkerName $_ } | Select-Object -First 1) { continue }

            $disk = $Disks | Where-Object { $gd.FullName.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $disk) { continue }

            # Gallery is FLAT (one-level): only files directly inside _gallery are synced.
            $files = Get-ChildItem -LiteralPath $gd.FullName -File -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $ext = $f.Extension.ToLowerInvariant()
                if ($ext -and ($GalleryExtensions -notcontains $ext)) { continue }

                $relPhone = Get-PhoneRelativeFromPcPath -DiskRoot $disk -PcPath $f.FullName
                if ([string]::IsNullOrWhiteSpace($relPhone)) { continue }

                $phoneKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $relPhone
                if ([string]::IsNullOrWhiteSpace($phoneKey)) { continue }

                $items += [pscustomobject]@{
                    DiskRoot      = $disk
                    PcPath        = $f.FullName
                    PhoneKey      = $phoneKey
                    PhoneBaseId   = $SsdBaseId
                    PhoneRelative = $relPhone
                    Size          = $f.Length
                    LastWriteUtc  = $f.LastWriteTimeUtc.ToString('o')
                }
            }
        }
    }

    # De-dup (prefer first)
    $byRel = @{}
    foreach ($it in $items) {
        if (-not $byRel.ContainsKey($it.PhoneKey)) { $byRel[$it.PhoneKey] = $it }
        else { Write-Warn "[WARN] Duplicate mapping to phone key: $($it.PhoneKey)" }
    }

    return $byRel
}

function Get-PhoneInventory {
    param(
        [switch]$IncludeMobile,
        [switch]$IncludeGallery
    )
    $map = @{}

    if (-not $phoneBaseFolder) { return $map }
    if (-not $IncludeMobile -and -not $IncludeGallery) { return $map }

    function Is-PhoneMobileRelative([string]$RelativePath) {
        if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
        $parts = ($RelativePath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        return [bool]($parts | Where-Object { $_ -ieq $PhoneMobileFolderName } | Select-Object -First 1)
    }

    Write-Info "[SCAN] Reading phone inventory under SSD ..."
    $allFiles = Get-MtpFilesRecursive -Folder $phoneBaseFolder
    foreach ($f in $allFiles) {
        $isMobile = Is-PhoneMobileRelative -RelativePath $f.RelativePath
        if ($IncludeMobile -and (-not $IncludeGallery) -and (-not $isMobile)) { continue }
        if ($IncludeGallery -and (-not $IncludeMobile) -and $isMobile) { continue }

        $key = New-PhoneKey -BaseId $SsdBaseId -RelativePath $f.RelativePath
        if (-not $key) { continue }
        $map[$key] = [pscustomobject]@{
            BaseId       = $SsdBaseId
            RelativePath = $f.RelativePath
            Name         = $f.Name
            Item         = $f.Item
            SizeBytes    = (Try-GetMtpItemSizeBytes -Item $f.Item)
            DateModified = (Try-GetMtpItemDateModified -Item $f.Item)
        }
    }

    return $map
}

function Get-PhoneMobileRootRelative([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $null }
    $parts = ($RelativePath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $idx = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ieq $PhoneMobileFolderName) { $idx = $i; break }
    }
    if ($idx -lt 0) { return $null }
    if ($idx -eq 0) { return $PhoneMobileFolderName }
    return ($parts[0..$idx] -join '\')
}

function Get-PhoneRelativeWithoutMobileSegment([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $null }
    $parts = ($RelativePath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $idx = -1
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if ($parts[$i] -ieq $PhoneMobileFolderName) { $idx = $i; break }
    }
    if ($idx -lt 0) { return $null }
    if ($idx -ge ($parts.Count - 1)) { return $null }

    if ($idx -eq 0) { return ($parts[1..($parts.Count - 1)] -join '\') }
    if ($idx -eq ($parts.Count - 1)) { return ($parts[0..($parts.Count - 2)] -join '\') }

    $before = $parts[0..($idx - 1)]
    $after = $parts[($idx + 1)..($parts.Count - 1)]
    return (($before + $after) -join '\')
}

function Ensure-PhoneNomediaInMobileRoot([string]$MobileRootRelative) {
    if ([string]::IsNullOrWhiteSpace($MobileRootRelative)) { return $false }
    if (-not $phoneBaseFolder) { return $false }

    $folder = $null
    try { $folder = Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $MobileRootRelative } catch { $folder = $null }
    if (-not $folder) { return $false }

    $existing = Find-MtpItemByName -Folder $folder -Name $NomediaFileName
    if ($existing) { return $true }

    if ($IsPreview) {
        Write-Warn "[WARN] Missing $NomediaFileName on phone: $MobileRootRelative\\$NomediaFileName"
        return $false
    }

    Write-Info "[FIX] Create $NomediaFileName on phone: $MobileRootRelative\\$NomediaFileName"
    Log "CREATE_NOMEDIA_PHONE $MobileRootRelative\\$NomediaFileName"

    if (-not (Test-Path -LiteralPath $nomediaTemplatePath)) {
        try { New-Item -Path $nomediaTemplatePath -ItemType File -Force | Out-Null } catch {}
    }

    return (Copy-PCFileToMtp -SourcePath $nomediaTemplatePath -SourceSizeBytes 0 -DestFolder $folder)
}

function Ensure-PcNomediaForMobilePath([string]$PcPath) {
    if ([string]::IsNullOrWhiteSpace($PcPath)) { return $false }
    if ($IsPreview) { return $false }

    $p = Split-Path -Path $PcPath -Parent
    while ($p -and (Split-Path -Path $p -Leaf) -ne '') {
        if (Is-MobileMarkerName (Split-Path -Path $p -Leaf)) {
            $nomediaPc = Join-Path $p $NomediaFileName
            if (-not (Test-Path -LiteralPath $nomediaPc)) {
                try { New-Item -Path $nomediaPc -ItemType File -Force | Out-Null } catch {}
            }
            return $true
        }
        $parent = Split-Path -Path $p -Parent
        if ($parent -eq $p) { break }
        $p = $parent
    }
    return $false
}

if ($Mode -eq 'PC2Phone') {
    $snapshotPath = Join-Path $stateDir 'snapshot_pc2phone.json'
    $snapshot = Load-Snapshot -Path $snapshotPath
    if (-not $snapshot) {
        $snapshot = [pscustomobject]@{ mode = 'PC2Phone'; generated = $null; items = @{} }
    }
    $snapshot.items = Ensure-Hashtable $snapshot.items

    # Backward-compat: older snapshots used SSD-relative keys without "<BaseId>::" prefix.
    foreach ($k in @($snapshot.items.Keys)) {
        if ($k -notmatch '::') {
            $newKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $k
            if ($newKey -and (-not $snapshot.items.ContainsKey($newKey))) {
                $snapshot.items[$newKey] = $snapshot.items[$k]
            }
            $null = $snapshot.items.Remove($k)
        }
    }

    $pcScopeRoots = @()
    if ($ScanRoots -and $ScanRoots.Count -gt 0) {
        foreach ($sr in $ScanRoots) {
            if ([string]::IsNullOrWhiteSpace($sr)) { continue }
            if (-not (Test-Path -LiteralPath $sr)) { continue }
            try {
                $it = Get-Item -LiteralPath $sr -ErrorAction SilentlyContinue
                if ($it -and $it.PSIsContainer) {
                    $p = $it.FullName.TrimEnd('\') + '\'
                    $pcScopeRoots += $p
                }
                elseif ($it) {
                    $p = (Split-Path -Path $it.FullName -Parent).TrimEnd('\') + '\'
                    $pcScopeRoots += $p
                }
            } catch {}
        }
    }
    $pcScopeRoots = $pcScopeRoots | Sort-Object -Unique
    $hasPcScope = ($pcScopeRoots.Count -gt 0)

    function Is-PcPathInScope([string]$PcPath, [string[]]$Roots) {
        if (-not $Roots -or $Roots.Count -eq 0) { return $true }
        if ([string]::IsNullOrWhiteSpace($PcPath)) { return $false }
        foreach ($r in $Roots) {
            if ([string]::IsNullOrWhiteSpace($r)) { continue }
            if ($PcPath.StartsWith($r, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }

    $phoneDeletePrefixes = @()
    if ($hasPcScope) {
        foreach ($r in $pcScopeRoots) {
            $disk = $connectedDisks | Where-Object { $r.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if (-not $disk) { continue }
            try {
                $prefix = Get-PhoneRelativeFromPcPath -DiskRoot $disk -PcPath $r
                $prefix = $prefix.Trim('\')
                if (-not [string]::IsNullOrWhiteSpace($prefix)) { $phoneDeletePrefixes += $prefix }
            } catch {}
        }
        $phoneDeletePrefixes = $phoneDeletePrefixes | Sort-Object -Unique
    }

    function Is-PhoneRelativeInScope([string]$RelativePath, [string[]]$Prefixes) {
        if (-not $Prefixes -or $Prefixes.Count -eq 0) { return $true }
        if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
        foreach ($p in $Prefixes) {
            if ([string]::IsNullOrWhiteSpace($p)) { return $true }
            if ($RelativePath.StartsWith($p + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
            if ($RelativePath.Equals($p, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }

    $desired = Build-PcMobileSelection -Disks $connectedDisks -ScanRoots $ScanRoots -IncludeMobile:$includeMobile -IncludeGallery:$includeGallery
    $phoneInv = Get-PhoneInventory -IncludeMobile:$includeMobile -IncludeGallery:$includeGallery

    $desiredCount = $desired.Keys.Count
    $phoneCount = $phoneInv.Keys.Count

    Write-Host ""
    Write-Host "Desired (PC Mobile selection): $desiredCount file(s)" -ForegroundColor Cyan
    Write-Host "Phone current: $phoneCount file(s)" -ForegroundColor Cyan
    Write-Host ""

    $toCopy = @()
    $toReplace = @()
    $alreadyOk = 0

    foreach ($k in $desired.Keys) {
        $d = $desired[$k]
        $existsOnPhone = $phoneInv.ContainsKey($k)

        if (-not $existsOnPhone) {
            $toCopy += $d
            continue
        }

        $pi = $phoneInv[$k]
        $phoneSize = $null
        try { $phoneSize = [int64]$pi.SizeBytes } catch { $phoneSize = $null }
        $phoneSizeKnown = ($phoneSize -and $phoneSize -gt 0)
        $phoneMatches = $false
        if ($phoneSizeKnown) { $phoneMatches = ([int64]$phoneSize -eq [int64]$d.Size) }

        $snapItem = $null
        if ($snapshot.items.ContainsKey($k)) { $snapItem = $snapshot.items[$k] }

        $pcUnchanged = $false
        if ($snapItem) {
            if ($snapItem.size -eq $d.Size -and $snapItem.lastWriteUtc -eq $d.LastWriteUtc) { $pcUnchanged = $true }
        }

        if (-not $snapItem) {
            if ($phoneSizeKnown -and $phoneMatches) { $alreadyOk++; continue }
            $toReplace += $d
            continue
        }

        if ($pcUnchanged) {
            if (-not $phoneSizeKnown) { $alreadyOk++; continue }
            if ($phoneMatches) { $alreadyOk++; continue }
            $toReplace += $d
            continue
        }

        $toReplace += $d
    }

    function Is-PhoneRelativeMobile([string]$RelativePath) {
        if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
        $parts = ($RelativePath -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        return [bool]($parts | Where-Object { $_ -ieq $PhoneMobileFolderName } | Select-Object -First 1)
    }

    # Determine deletions on phone (only managed by snapshot unless -Force)
    $toDelete = @()
    $skipUnmanaged = 0
    $skipOutOfScope = 0

    # Legacy cleanup: old sync versions could copy _mobile content outside of "Mobile\".
    # If both copies exist, we can safely delete the outside one only when sizes match.
    $legacyMobileDupKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $legacyMobileDupSkipped = 0
    if ($includeMobile -and $includeGallery) {
        foreach ($pi2 in $phoneInv.Values) {
            if (-not $pi2) { continue }
            if (-not (Is-PhoneRelativeMobile -RelativePath $pi2.RelativePath)) { continue }

            $altRel = Get-PhoneRelativeWithoutMobileSegment -RelativePath $pi2.RelativePath
            if ([string]::IsNullOrWhiteSpace($altRel)) { continue }

            $altKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $altRel
            if ([string]::IsNullOrWhiteSpace($altKey)) { continue }
            if (-not $phoneInv.ContainsKey($altKey)) { continue }

            $outside = $phoneInv[$altKey]
            if (-not $outside) { continue }

            $mobileSize = 0
            $outsideSize = 0
            try { $mobileSize = [int64]$pi2.SizeBytes } catch { $mobileSize = 0 }
            try { $outsideSize = [int64]$outside.SizeBytes } catch { $outsideSize = 0 }

            if ($mobileSize -gt 0 -and $outsideSize -gt 0 -and $mobileSize -eq $outsideSize) {
                $null = $legacyMobileDupKeys.Add($altKey)
            }
            else {
                $legacyMobileDupSkipped++
            }
        }

        if ($legacyMobileDupKeys.Count -gt 0) {
            Write-Warn "[WARN] Legacy duplicates (outside Mobile) found on phone: $($legacyMobileDupKeys.Count)"
        }
        if ($legacyMobileDupSkipped -gt 0) {
            Write-Warn "[WARN] Legacy duplicates skipped (size unknown/mismatch): $legacyMobileDupSkipped"
        }
    }

    foreach ($k in $phoneInv.Keys) {
        if ($desired.ContainsKey($k)) { continue }

        $pi = $phoneInv[$k]
        if (-not $pi) { continue }

        # Never delete .nomedia (it protects mobile folders from Google Photos indexing)
        $leaf = Split-Path -Path $pi.RelativePath -Leaf
        if ($leaf -ieq $NomediaFileName) { continue }

        if ($hasPcScope) {
            if (-not (Is-PhoneRelativeInScope -RelativePath $pi.RelativePath -Prefixes $phoneDeletePrefixes)) { $skipOutOfScope++; continue }
        }

        $isLegacyMobileDup = $legacyMobileDupKeys.Contains($k)

        # Safety: only delete files that were previously managed by PC2Phone (snapshot), unless -Force.
        # Exception: legacy duplicates (outside Mobile) can be deleted even if unmanaged (they have a matching copy in Mobile, sizes match).
        $snapItem = $null
        if ($snapshot.items.ContainsKey($k)) { $snapItem = $snapshot.items[$k] }
        if (-not $Force -and (-not $snapItem) -and (-not $isLegacyMobileDup)) { $skipUnmanaged++; continue }
        if ($hasPcScope -and (-not $Force) -and $snapItem) {
            $pcp = $null
            try { $pcp = [string]$snapItem.pcPath } catch { $pcp = $null }
            if (-not (Is-PcPathInScope -PcPath $pcp -Roots $pcScopeRoots)) { $skipOutOfScope++; continue }
        }

        $root = ($pi.RelativePath -split '\\')[0]
        $isYear = Is-YearName $root

        $manageThisRoot = $true
        if ($singleDiskSafeMode -and $isSingleDisk) {
            # In single-disk safe mode: do NOT touch non-year roots (Family, Projects, etc.)
            if (-not $isYear) { $manageThisRoot = $false }
            else {
                $y = [int]$root
                if ($y -ge $recentYearStart) {
                    $manageThisRoot = ($connectedDisks -contains $recentDiskDetected)
                } else {
                    $manageThisRoot = ($connectedDisks -contains $oldDiskDetected)
                }
            }
        }

        if (-not $manageThisRoot) { continue }
        $toDelete += $pi
    }

    if (-not $Force -and $skipUnmanaged -gt 0) {
        Write-Warn "[WARN] Skipping $skipUnmanaged phone file(s): not managed by snapshot (phone-only). Use -Force to include them."
    }
    if ($skipOutOfScope -gt 0) {
        Write-Warn "[WARN] Skipping $skipOutOfScope phone file(s): out of ScanRoots scope."
    }

    $copyMobile = @($toCopy | Where-Object { Is-PhoneRelativeMobile $_.PhoneRelative }).Count
    $copyGallery = $toCopy.Count - $copyMobile
    $repMobile = @($toReplace | Where-Object { Is-PhoneRelativeMobile $_.PhoneRelative }).Count
    $repGallery = $toReplace.Count - $repMobile
    $delMobile = @($toDelete | Where-Object { Is-PhoneRelativeMobile $_.RelativePath }).Count
    $delGallery = $toDelete.Count - $delMobile

    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  Copy new    : $($toCopy.Count) (Gallery: $copyGallery, Mobile: $copyMobile)" -ForegroundColor White
    Write-Host "  Replace     : $($toReplace.Count) (Gallery: $repGallery, Mobile: $repMobile)" -ForegroundColor White
    Write-Host "  Delete phone: $($toDelete.Count) (Gallery: $delGallery, Mobile: $delMobile)" -ForegroundColor White
    Write-Info "  Already OK  : $alreadyOk (exists on phone, matches by size/snapshot)"
    if ($toDelete.Count -gt $MaxDeletes) {
        Write-Fail "[ERROR] Too many deletes ($($toDelete.Count) > $MaxDeletes). Refusing."
        exit 1
    }

    Log "PLAN Copy=$($toCopy.Count) Replace=$($toReplace.Count) DeletePhone=$($toDelete.Count) (Gallery Copy=$copyGallery Replace=$repGallery Delete=$delGallery; Mobile Copy=$copyMobile Replace=$repMobile Delete=$delMobile)"

    if ($IsPreview) {
        Write-Warn "`n[PREVIEW] No changes made. Re-run with -Execute to apply."
        exit 0
    }

    if ($requireConfirmation -and (-not $Yes)) {
        Write-Host ""
        $ans = Read-Host "Proceed with EXECUTE? Type YES to continue"
        if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
    }

    # Execute copies
    $copyOk = 0
    $copyFail = 0
    $i = 0

    foreach ($d in $toCopy) {
        $i++
        Write-Host "[$i/$($toCopy.Count)] COPY -> [$($d.PhoneBaseId)] $($d.PhoneRelative)" -ForegroundColor Cyan
        Log "COPY [$($d.PhoneBaseId)] $($d.PcPath) -> $($d.PhoneRelative)"

        $destDirRel = Split-Path -Path $d.PhoneRelative -Parent
        if ($destDirRel -eq '.' -or [string]::IsNullOrWhiteSpace($destDirRel)) { $destDirRel = '' }
        $destFolder = Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $destDirRel

        $ok = Copy-PCFileToMtp -SourcePath $d.PcPath -SourceSizeBytes $d.Size -DestFolder $destFolder
        if ($ok) {
            $copyOk++
            $snapshot.items[$d.PhoneKey] = [pscustomobject]@{ pcPath = $d.PcPath; size = $d.Size; lastWriteUtc = $d.LastWriteUtc }
            try { Save-Snapshot -Path $snapshotPath -Obj $snapshot } catch {}
            Write-Ok "  [OK]"
        }
        else {
            $copyFail++
            Write-Fail "  [FAIL]"
        }
    }

    # Execute replacements (delete then copy)
    $repOk = 0
    $repFail = 0
    $j = 0
    foreach ($d in $toReplace) {
        $j++
        Write-Host "[$j/$($toReplace.Count)] REPLACE -> [$($d.PhoneBaseId)] $($d.PhoneRelative)" -ForegroundColor Cyan
        Log "REPLACE [$($d.PhoneBaseId)] $($d.PcPath) -> $($d.PhoneRelative)"

        $destDirRel = Split-Path -Path $d.PhoneRelative -Parent
        if ($destDirRel -eq '.' -or [string]::IsNullOrWhiteSpace($destDirRel)) { $destDirRel = '' }
        $destFolder = Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $destDirRel

        $fileName = Split-Path -Path $d.PhoneRelative -Leaf
        $null = Remove-MtpFile -ParentFolder $destFolder -FileName $fileName

        $ok = Copy-PCFileToMtp -SourcePath $d.PcPath -SourceSizeBytes $d.Size -DestFolder $destFolder
        if ($ok) {
            $repOk++
            $snapshot.items[$d.PhoneKey] = [pscustomobject]@{ pcPath = $d.PcPath; size = $d.Size; lastWriteUtc = $d.LastWriteUtc }
            try { Save-Snapshot -Path $snapshotPath -Obj $snapshot } catch {}
            Write-Ok "  [OK]"
        }
        else {
            $repFail++
            Write-Fail "  [FAIL]"
        }
    }

    # Execute deletes on phone
    $delOk = 0
    $delFail = 0

    if ($toDelete.Count -gt 0) {
        Write-Host ""
        $doDeletes = $Yes
        if (-not $doDeletes) {
            $ans2 = Read-Host "Delete $($toDelete.Count) file(s) from PHONE? Type YES to proceed"
            $doDeletes = ($ans2 -eq 'YES')
        }
        if (-not $doDeletes) {
            Write-Warn "Skip phone deletions."
        }
        else {
            $k = 0
            foreach ($f in $toDelete) {
                $k++
                Write-Host "[$k/$($toDelete.Count)] DELETE phone -> [$($f.BaseId)] $($f.RelativePath)" -ForegroundColor Yellow
                Log "DELETE_PHONE [$($f.BaseId)] $($f.RelativePath)"

                $parentRel = Split-Path -Path $f.RelativePath -Parent
                if ($parentRel -eq '.' -or [string]::IsNullOrWhiteSpace($parentRel)) { $parentRel = '' }
                $parentFolder = if ($parentRel) { Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $parentRel } else { $phoneBaseFolder }
                $ok = Remove-MtpFile -ParentFolder $parentFolder -FileName $f.Name
                if ($ok) {
                    $delOk++
                    $delKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $f.RelativePath
                    if ($delKey -and $snapshot.items.ContainsKey($delKey)) {
                        $null = $snapshot.items.Remove($delKey)
                    }
                }
                else { $delFail++ }
            }
        }
    }

    $snapshot.generated = (Get-Date).ToString('o')
    $snapshot.version = '2026-01-05'
    Save-Snapshot -Path $snapshotPath -Obj $snapshot

    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Copied   : $copyOk OK, $copyFail FAIL"
    Write-Host "  Replaced : $repOk OK, $repFail FAIL"
    Write-Host "  Deleted  : $delOk OK, $delFail FAIL"
    Write-Host "Log: $logPath" -ForegroundColor Gray
    exit 0
}

if ($Mode -eq 'Phone2PC' -or $Mode -eq 'Phone2PCDelete') {
    $phoneInv = Get-PhoneInventory -IncludeMobile:$includeMobile -IncludeGallery:$includeGallery

    # Snapshot (PC2Phone) used as a safety guard to avoid re-importing files that were originally synced from PC.
    $pc2PhoneSnapshotPath = Join-Path $stateDir 'snapshot_pc2phone.json'
    $pc2PhoneSnap = Load-Snapshot -Path $pc2PhoneSnapshotPath
    $pc2PhoneSnapItems = @{}
    if ($pc2PhoneSnap -and $pc2PhoneSnap.items) {
        $pc2PhoneSnapItems = Ensure-Hashtable $pc2PhoneSnap.items
        foreach ($sk in @($pc2PhoneSnapItems.Keys)) {
            if ($sk -notmatch '::') {
                $newKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $sk
                if ($newKey -and (-not $pc2PhoneSnapItems.ContainsKey($newKey))) { $pc2PhoneSnapItems[$newKey] = $pc2PhoneSnapItems[$sk] }
                $null = $pc2PhoneSnapItems.Remove($sk)
            }
        }
    }

    # Map phone -> PC destinations
    $mapped = @()
    $ambiguousThemes = @()

    foreach ($k in $phoneInv.Keys) {
        $pi = $phoneInv[$k]
        if (-not $pi) { continue }

        $disk = $null
        $pcPath = $null

        if ($pi.BaseId -eq $SsdBaseId) {
            $root = ($pi.RelativePath -split '\\')[0]
            $disk = Resolve-DiskForPhoneRoot -RootName $root -ConnectedDisks $connectedDisks
            if (-not $disk) {
                Write-Warn "[SKIP] Cannot resolve disk for root '$root' (likely missing disk connected)."
                continue
            }
            if (-not (Is-DiskAllowed $disk)) { continue }

            # theme ambiguity
            if (-not (Is-YearName $root)) {
                $hits = @()
                foreach ($d in $connectedDisks) { if (Test-Path -LiteralPath (Join-Path $d $root)) { $hits += $d } }
                if ($hits.Count -gt 1) { $ambiguousThemes += $root }
            }

            $pcPath = Get-PcPathFromPhoneRelative -DiskRoot $disk -PhoneRelative $pi.RelativePath
        }
        # Phone inventory only includes SSD base; BaseId is always SSD.
        else { continue }

        if (-not $pcPath) { continue }

        $mapped += [pscustomobject]@{
            PhoneKey      = $k
            PhoneBaseId   = $pi.BaseId
            PhoneRelative = $pi.RelativePath
            PhoneItem     = $pi.Item
            PhoneSizeBytes = (Try-GetMtpItemSizeBytes -Item $pi.Item)
            PhoneDateModified = (Try-GetMtpItemDateModified -Item $pi.Item)
            PcPath        = $pcPath
            DiskRoot      = $disk
        }
    }

    $ambiguousThemes = $ambiguousThemes | Select-Object -Unique
    if ($ambiguousThemes.Count -gt 0) {
        Write-Warn "[WARN] Theme folders exist on multiple disks (ambiguous): $($ambiguousThemes -join ', ')"
        Write-Warn "       Consider keeping themes on a single disk only."
    }

    $toCopy = @()
    $toReplacePc = @()
    foreach ($m in $mapped) {
        if (-not (Test-Path -LiteralPath $m.PcPath)) { $toCopy += $m; continue }

        # Replace support (e.g., trimmed videos): if the phone file differs, overwrite on PC.

        $pcFile = $null
        try { $pcFile = Get-Item -LiteralPath $m.PcPath -ErrorAction SilentlyContinue } catch { $pcFile = $null }
        if (-not $pcFile) { continue }

        $sizeMismatch = $false
        if ($m.PhoneSizeBytes -and $m.PhoneSizeBytes -gt 0) {
            $sizeMismatch = ([int64]$pcFile.Length -ne [int64]$m.PhoneSizeBytes)
        }

        $dateMismatch = $false
        if (-not $sizeMismatch -and $m.PhoneDateModified) {
            try {
                $deltaMinutes = [math]::Abs((([datetime]$pcFile.LastWriteTime) - ([datetime]$m.PhoneDateModified)).TotalMinutes)
                if ($deltaMinutes -ge 2) { $dateMismatch = $true }
            } catch { $dateMismatch = $false }
        }

        if ($sizeMismatch -or $dateMismatch) { $toReplacePc += $m }
    }

    Write-Host ""
    Write-Host "Phone files considered: $($mapped.Count)" -ForegroundColor Cyan
    Write-Host "Copy to PC (new): $($toCopy.Count)" -ForegroundColor Cyan
    Write-Host "Replace on PC: $($toReplacePc.Count)" -ForegroundColor Yellow

    $toDeletePc = @()
    if ($Mode -eq 'Phone2PCDelete') {
        # Scan current PC Mobile selection (in-scope) and delete those missing on phone
        $pcSelection = Build-PcMobileSelection -Disks $connectedDisks -ScanRoots $ScanRoots -IncludeMobile:$includeMobile -IncludeGallery:$includeGallery
        $skipNotSynced = 0

        # Safety: only delete files that were previously synced to phone (snapshot), unless -Force.
        $snapshotPath = Join-Path $stateDir 'snapshot_pc2phone.json'
        $snap = Load-Snapshot -Path $snapshotPath
        $snapItems = @{}
        if ($snap -and $snap.items) {
            $snapItems = Ensure-Hashtable $snap.items
            foreach ($sk in @($snapItems.Keys)) {
                if ($sk -notmatch '::') {
                    $newKey = New-PhoneKey -BaseId $SsdBaseId -RelativePath $sk
                    if ($newKey -and (-not $snapItems.ContainsKey($newKey))) { $snapItems[$newKey] = $snapItems[$sk] }
                    $null = $snapItems.Remove($sk)
                }
            }
        }

        foreach ($pk in $pcSelection.Keys) {
            $leafName = Split-Path -Path $pcSelection[$pk].PcPath -Leaf
            if ($leafName -ieq $NomediaFileName) { continue }
            if ($phoneInv.ContainsKey($pk)) { continue }
            if ($Force -or ($snapItems.ContainsKey($pk))) {
                $toDeletePc += $pcSelection[$pk]
            }
            else {
                $skipNotSynced++
            }
        }

        if ($skipNotSynced -gt 0 -and (-not $Force)) {
            Write-Warn "[WARN] Skipping $skipNotSynced PC file(s) missing on phone because they were never synced (no snapshot match). Use -Force to include them."
        }

        Write-Host "Delete on PC: $($toDeletePc.Count)" -ForegroundColor Yellow
        if ($toDeletePc.Count -gt $MaxDeletes) {
            Write-Fail "[ERROR] Too many deletes ($($toDeletePc.Count) > $MaxDeletes). Refusing."
            exit 1
        }
    }

    Log "PLAN CopyToPC=$($toCopy.Count) ReplaceOnPC=$($toReplacePc.Count) DeleteOnPC=$($toDeletePc.Count)"

    if ($IsPreview) {
        Write-Warn "`n[PREVIEW] No changes made. Re-run with -Execute to apply."
        exit 0
    }

    if ($requireConfirmation -and (-not $Yes)) {
        Write-Host ""
        $ans = Read-Host "Proceed with EXECUTE? Type YES to continue"
        if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
        if ($Mode -eq 'Phone2PCDelete') {
            $ans2 = Read-Host "This mode can DELETE from PC. Type DELETE to continue"
            if ($ans2 -ne 'DELETE') { Write-Warn "Cancelled."; exit 0 }
        }
    }

    if ($includeMobile) {
        $mobileRoots = @()
        foreach ($pi in $phoneInv.Values) {
            $mr = Get-PhoneMobileRootRelative -RelativePath $pi.RelativePath
            if ($mr) { $mobileRoots += $mr }
        }
        $mobileRoots = $mobileRoots | Select-Object -Unique
        foreach ($mr in $mobileRoots) {
            $null = Ensure-PhoneNomediaInMobileRoot -MobileRootRelative $mr
        }
    }

    # Execute copy Phone -> PC (new)
    $ok = 0
    $fail = 0
    $i = 0
    foreach ($m in $toCopy) {
        $i++
        $destDir = Split-Path -Path $m.PcPath -Parent
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        $null = Ensure-PcNomediaForMobilePath -PcPath $m.PcPath

        Write-Host "[$i/$($toCopy.Count)] COPY phone [$($m.PhoneBaseId)] $($m.PhoneRelative) -> $($m.PcPath)" -ForegroundColor Cyan
        Log "COPY_PHONE [$($m.PhoneBaseId)] $($m.PhoneRelative) -> $($m.PcPath)"

        $copied = Copy-MtpItemToPC -MtpItem $m.PhoneItem -DestDir $destDir -ExpectedSizeBytes ([int64]$m.PhoneSizeBytes)
        if ($copied) { $ok++; Write-Ok "  [OK]" } else { $fail++; Write-Fail "  [FAIL]" }
    }

    # Execute replacements on PC (Recycle Bin -> copy)
    $repOk = 0
    $repFail = 0
    if ($toReplacePc.Count -gt 0) {
        $r = 0
        foreach ($m in $toReplacePc) {
            $r++
            $destDir = Split-Path -Path $m.PcPath -Parent
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            $null = Ensure-PcNomediaForMobilePath -PcPath $m.PcPath

            Write-Host "[$r/$($toReplacePc.Count)] REPLACE phone [$($m.PhoneBaseId)] $($m.PhoneRelative) -> $($m.PcPath)" -ForegroundColor Yellow
            Log "REPLACE_PHONE [$($m.PhoneBaseId)] $($m.PhoneRelative) -> $($m.PcPath)"

            $moved = Delete-ToRecycleBin -Path $m.PcPath
            if (-not $moved) { $repFail++; Write-Fail "  [FAIL] Could not move existing file to Recycle Bin"; continue }

            $copied = Copy-MtpItemToPC -MtpItem $m.PhoneItem -DestDir $destDir -ExpectedSizeBytes ([int64]$m.PhoneSizeBytes)
            if ($copied) { $repOk++; Write-Ok "  [OK]" } else { $repFail++; Write-Fail "  [FAIL]" }
        }
    }

    # Execute deletions on PC (Recycle Bin)
    $delOk = 0
    $delFail = 0
    if ($Mode -eq 'Phone2PCDelete' -and $toDeletePc.Count -gt 0) {
        $k = 0
        foreach ($d in $toDeletePc) {
            $k++
            Write-Host "[$k/$($toDeletePc.Count)] DELETE pc -> $($d.PcPath)" -ForegroundColor Yellow
            Log "DELETE_PC $($d.PcPath)"

            $moved = Delete-ToRecycleBin -Path $d.PcPath
            if ($moved) { $delOk++ } else { $delFail++ }
        }

        # Cleanup empty Mobile folders
        $mobileFolders = $toDeletePc | ForEach-Object { Split-Path -Path $_.PcPath -Parent } |
        ForEach-Object {
            $p = $_
            while ($p -and (Split-Path -Path $p -Leaf) -ne '') {
                if (Is-MobileMarkerName (Split-Path -Path $p -Leaf)) { $p; break }
                $p = Split-Path -Path $p -Parent
            }
        } | Select-Object -Unique

        foreach ($mf in $mobileFolders) {
            try {
                $left = Get-ChildItem -LiteralPath $mf -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ine $NomediaFileName }
                if (-not $left -or $left.Count -eq 0) {
                    Remove-Item -LiteralPath $mf -Recurse -Force
                    Log "DELETE_EMPTY_DIR $mf"
                }
            } catch {}
        }
    }

    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Copied to PC: $ok OK, $fail FAIL"
    Write-Host "  Replaced on PC: $repOk OK, $repFail FAIL"
    if ($Mode -eq 'Phone2PCDelete') {
        Write-Host "  Deleted on PC: $delOk OK, $delFail FAIL"
    }
    Write-Host "Log: $logPath" -ForegroundColor Gray
    exit 0
}

Write-Fail "[ERROR] Unhandled mode: $Mode"
exit 1
