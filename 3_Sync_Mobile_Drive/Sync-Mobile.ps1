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
#   - Phone path is accessed via Windows Shell (MTP): "PC\Pixel 8\...\DCIM\SSD"
#   - "Mobile" folders on PC are collapsed on phone (Mobile segment removed)
#   - In reverse mapping, "Mobile" is inserted after:
#       * Year root:     <YEAR>\Mobile\...
#       * Event/theme:   <ROOT>\<EVENT>\Mobile\...
# ============================================================================

param(
    [ValidateSet('PC2Phone', 'Phone2PC', 'Phone2PCDelete')]
    [string]$Mode = '',

    [ValidateSet('Both', 'Recent', 'Old')]
    [string]$SourceDisk = 'Both',

    [string]$ConfigPath = "$PSScriptRoot\\device_config.json",

    [string[]]$ScanRoots = @(),

    [switch]$WhatIf,
    [switch]$Execute,

    [switch]$Force,

    [int]$MaxDeletes = 5000
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

$IsPreview = $WhatIf -or (-not $Execute)

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

        $rel = if ([string]::IsNullOrEmpty($RelativePrefix)) { $it.Name } else { "$RelativePrefix\$($it.Name)" }
        $results += [pscustomobject]@{
            RelativePath = $rel
            Name         = $it.Name
            Item         = $it
        }
    }
    return $results
}

function Find-MtpItemByName {
    param($Folder, [string]$Name)
    foreach ($it in $Folder.Items()) {
        if (-not $it.IsFolder -and $it.Name -ieq $Name) { return $it }
    }
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

function Copy-PCFileToMtp {
    param(
        [string]$SourcePath,
        $DestFolder
    )

    $fileName = Split-Path -Path $SourcePath -Leaf
    $DestFolder.CopyHere($SourcePath, 16) | Out-Null # 16 = no confirmation

    $tries = 0
    while ($tries -lt 600) {
        $it = Find-MtpItemByName -Folder $DestFolder -Name $fileName
        if ($it) { return $true }
        Start-Sleep -Milliseconds 500
        $tries++
    }
    return $false
}

function Copy-MtpItemToPC {
    param(
        $MtpItem,
        [string]$DestDir
    )

    $shell = Get-ShellApp
    $destFolder = $shell.Namespace($DestDir)
    if (-not $destFolder) { throw "Cannot open destination folder: $DestDir" }

    $destFolder.CopyHere($MtpItem, 16) | Out-Null

    $destPath = Join-Path $DestDir $MtpItem.Name
    $tries = 0
    while ($tries -lt 600) {
        if (Test-Path -LiteralPath $destPath) { return $true }
        Start-Sleep -Milliseconds 500
        $tries++
    }
    return $false
}

function Collapse-MobileFromPathSegments([string[]]$Segments) {
    return @($Segments | Where-Object { $_ -and ($_ -notmatch '^[\\/]+$') } | Where-Object { $_ -ine 'Mobile' })
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
    $collapsed = Collapse-MobileFromPathSegments -Segments $segs
    return ($collapsed -join '\')
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

    $insertIndex = 0
    if ($dirSegs.Count -ge 2) { $insertIndex = 2 } elseif ($dirSegs.Count -eq 1) { $insertIndex = 1 } else { $insertIndex = 0 }

    $newDirSegs = @()
    if ($insertIndex -gt 0) { $newDirSegs += $dirSegs[0..($insertIndex - 1)] }
    $newDirSegs += 'Mobile'
    if ($insertIndex -lt $dirSegs.Count) { $newDirSegs += $dirSegs[$insertIndex..($dirSegs.Count - 1)] }

    $destDir = Join-Path $DiskRoot ($newDirSegs -join '\')
    return Join-Path $destDir $fileName
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
Write-Host "PhoneBase: $phoneBasePath"
Write-Host "Disks (connected): $($connectedDisks -join ', ')"
Write-Host "Detected recent disk (>= $recentYearStart): $(if ($recentDiskDetected) { $recentDiskDetected } else { 'N/A' })" -ForegroundColor Gray
Write-Host "Detected old disk (<  $recentYearStart): $(if ($oldDiskDetected) { $oldDiskDetected } else { 'N/A' })" -ForegroundColor Gray
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
Write-Host "SourceDisk filter: $SourceDisk"
if ($ScanRoots -and $ScanRoots.Count -gt 0) { Write-Host "ScanRoots: $($ScanRoots -join ', ')" -ForegroundColor Gray }
if ($isSingleDisk) { Write-Warn "[WARN] Single-disk detected: $($connectedDisks[0])" }
Write-Host ""

Log "START Mode=$Mode Preview=$IsPreview SourceDisk=$SourceDisk"
Log "PhoneBase=$phoneBasePath"
Log "ConnectedDisks=$($connectedDisks -join ', ')"
if ($config.disks.recent.path -and $recentDiskDetected -and (Normalize-Root $config.disks.recent.path) -ne $recentDiskDetected) {
    Write-Warn "[WARN] Config recent disk ($($config.disks.recent.path)) differs from detected ($recentDiskDetected)."
}
if ($config.disks.old.path -and $oldDiskDetected -and (Normalize-Root $config.disks.old.path) -ne $oldDiskDetected) {
    Write-Warn "[WARN] Config old disk ($($config.disks.old.path)) differs from detected ($oldDiskDetected)."
}

# Connect to phone base folder (MTP)
$phoneBaseFolder = $null
try { $phoneBaseFolder = Get-PhoneBaseFolder -BasePath $phoneBasePath } catch { $phoneBaseFolder = $null }
if (-not $phoneBaseFolder) {
    Write-Fail "[ERROR] Cannot access phone base path via Shell: $phoneBasePath"
    Write-Warn "Ensure Pixel 8 is connected and unlocked, and DCIM\\SSD exists."
    exit 1
}

Write-Ok "[OK] Phone path reachable: $phoneBasePath"

function Build-PcMobileSelection {
    param(
        [string[]]$Disks,
        [string[]]$ScanRoots
    )

    $mobileDirs = @()
    foreach ($d in $Disks) {
        if (-not (Is-DiskAllowed $d)) { continue }
        $rootsToScan = @()
        if ($ScanRoots -and $ScanRoots.Count -gt 0) {
            foreach ($sr in $ScanRoots) {
                if (-not $sr) { continue }
                if (-not (Test-Path -LiteralPath $sr)) { continue }
                $rp = (Resolve-Path -LiteralPath $sr).Path.TrimEnd('\')
                if ($rp.StartsWith($d, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $rootsToScan += $rp
                }
            }
        }
        else {
            $rootsToScan = @($d.TrimEnd('\'))
        }

        if ($rootsToScan.Count -eq 0) { continue }

        foreach ($root in ($rootsToScan | Select-Object -Unique)) {
            Write-Info "[SCAN] Searching Mobile folders in $root ..."
            try {
                $rootItem = Get-Item -LiteralPath $root -ErrorAction SilentlyContinue
                if ($rootItem -and $rootItem.PSIsContainer -and $rootItem.Name -ieq 'Mobile') {
                    $mobileDirs += $rootItem
                }
            } catch {}

            $found = Get-ChildItem -LiteralPath $root -Directory -Recurse -Filter Mobile -ErrorAction SilentlyContinue
            if ($found) { $mobileDirs += ($found | Where-Object { $_.Name -ieq 'Mobile' }) }
        }
    }

    $mobileDirs = $mobileDirs | Select-Object -Unique
    $items = @()

    foreach ($dir in $mobileDirs) {
        $disk = $Disks | Where-Object { $dir.FullName.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        if (-not $disk) { continue }

        $files = Get-ChildItem -LiteralPath $dir.FullName -File -Recurse -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $relPhone = Get-PhoneRelativeFromPcPath -DiskRoot $disk -PcPath $f.FullName
            if ([string]::IsNullOrWhiteSpace($relPhone)) { continue }
            $items += [pscustomobject]@{
                DiskRoot      = $disk
                PcPath        = $f.FullName
                PhoneRelative = $relPhone
                Size          = $f.Length
                LastWriteUtc  = $f.LastWriteTimeUtc.ToString('o')
            }
        }
    }

    # De-dup (prefer first)
    $byRel = @{}
    foreach ($it in $items) {
        if (-not $byRel.ContainsKey($it.PhoneRelative)) { $byRel[$it.PhoneRelative] = $it }
        else { Write-Warn "[WARN] Duplicate mapping to phone path: $($it.PhoneRelative)"; }
    }

    return $byRel
}

function Get-PhoneInventory {
    Write-Info "[SCAN] Reading phone inventory under DCIM\\SSD ..."
    $files = Get-MtpFilesRecursive -Folder $phoneBaseFolder
    $map = @{}
    foreach ($f in $files) { $map[$f.RelativePath] = $f }
    return $map
}

if ($Mode -eq 'PC2Phone') {
    $snapshotPath = Join-Path $stateDir 'snapshot_pc2phone.json'
    $snapshot = Load-Snapshot -Path $snapshotPath
    if (-not $snapshot) {
        $snapshot = [pscustomobject]@{ mode = 'PC2Phone'; generated = $null; items = @{} }
    }
    $snapshot.items = Ensure-Hashtable $snapshot.items

    $desired = Build-PcMobileSelection -Disks $connectedDisks -ScanRoots $ScanRoots
    $phoneInv = Get-PhoneInventory

    $desiredCount = $desired.Keys.Count
    $phoneCount = $phoneInv.Keys.Count

    Write-Host ""
    Write-Host "Desired (PC Mobile selection): $desiredCount file(s)" -ForegroundColor Cyan
    Write-Host "Phone current: $phoneCount file(s)" -ForegroundColor Cyan
    Write-Host ""

    $toCopy = @()
    $toReplace = @()

    foreach ($k in $desired.Keys) {
        $d = $desired[$k]
        $existsOnPhone = $phoneInv.ContainsKey($k)
        $snapItem = $null
        if ($snapshot.items.ContainsKey($k)) { $snapItem = $snapshot.items[$k] }

        $pcUnchanged = $false
        if ($snapItem) {
            if ($snapItem.size -eq $d.Size -and $snapItem.lastWriteUtc -eq $d.LastWriteUtc) { $pcUnchanged = $true }
        }

        if (-not $existsOnPhone) {
            $toCopy += $d
        }
        elseif (-not $pcUnchanged) {
            $toReplace += $d
        }
    }

    $managedRoots = @{}
    foreach ($k in $desired.Keys) {
        $root = ($k -split '\\')[0]
        $managedRoots[$root] = $true
    }

    # Determine deletions on phone
    $toDelete = @()
    foreach ($k in $phoneInv.Keys) {
        if ($desired.ContainsKey($k)) { continue }

        $root = ($k -split '\\')[0]
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
        $toDelete += $phoneInv[$k]
    }

    Write-Host "Plan:" -ForegroundColor Cyan
    Write-Host "  Copy new    : $($toCopy.Count)" -ForegroundColor White
    Write-Host "  Replace     : $($toReplace.Count)" -ForegroundColor White
    Write-Host "  Delete phone: $($toDelete.Count)" -ForegroundColor White
    if ($toDelete.Count -gt $MaxDeletes) {
        Write-Fail "[ERROR] Too many deletes ($($toDelete.Count) > $MaxDeletes). Refusing."
        exit 1
    }

    Log "PLAN Copy=$($toCopy.Count) Replace=$($toReplace.Count) DeletePhone=$($toDelete.Count)"

    if ($IsPreview) {
        Write-Warn "`n[PREVIEW] No changes made. Re-run with -Execute to apply."
        exit 0
    }

    if ($requireConfirmation) {
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
        Write-Host "[$i/$($toCopy.Count)] COPY -> $($d.PhoneRelative)" -ForegroundColor Cyan
        Log "COPY $($d.PcPath) -> $($d.PhoneRelative)"

        $destDirRel = Split-Path -Path $d.PhoneRelative -Parent
        if ($destDirRel -eq '.' -or [string]::IsNullOrWhiteSpace($destDirRel)) { $destDirRel = '' }
        $destFolder = Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $destDirRel

        $ok = Copy-PCFileToMtp -SourcePath $d.PcPath -DestFolder $destFolder
        if ($ok) {
            $copyOk++
            $snapshot.items[$d.PhoneRelative] = [pscustomobject]@{ pcPath = $d.PcPath; size = $d.Size; lastWriteUtc = $d.LastWriteUtc }
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
        Write-Host "[$j/$($toReplace.Count)] REPLACE -> $($d.PhoneRelative)" -ForegroundColor Cyan
        Log "REPLACE $($d.PcPath) -> $($d.PhoneRelative)"

        $destDirRel = Split-Path -Path $d.PhoneRelative -Parent
        if ($destDirRel -eq '.' -or [string]::IsNullOrWhiteSpace($destDirRel)) { $destDirRel = '' }
        $destFolder = Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $destDirRel

        $fileName = Split-Path -Path $d.PhoneRelative -Leaf
        $null = Remove-MtpFile -ParentFolder $destFolder -FileName $fileName

        $ok = Copy-PCFileToMtp -SourcePath $d.PcPath -DestFolder $destFolder
        if ($ok) {
            $repOk++
            $snapshot.items[$d.PhoneRelative] = [pscustomobject]@{ pcPath = $d.PcPath; size = $d.Size; lastWriteUtc = $d.LastWriteUtc }
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
        $ans2 = Read-Host "Delete $($toDelete.Count) file(s) from PHONE? Type YES to proceed"
        if ($ans2 -ne 'YES') {
            Write-Warn "Skip phone deletions."
        }
        else {
            $k = 0
            foreach ($f in $toDelete) {
                $k++
                Write-Host "[$k/$($toDelete.Count)] DELETE phone -> $($f.RelativePath)" -ForegroundColor Yellow
                Log "DELETE_PHONE $($f.RelativePath)"

                $parentRel = Split-Path -Path $f.RelativePath -Parent
                if ($parentRel -eq '.' -or [string]::IsNullOrWhiteSpace($parentRel)) { $parentRel = '' }
                $parentFolder = if ($parentRel) { Ensure-MtpFolder -BaseFolder $phoneBaseFolder -RelativeDir $parentRel } else { $phoneBaseFolder }
                $ok = Remove-MtpFile -ParentFolder $parentFolder -FileName $f.Name
                if ($ok) { $delOk++ } else { $delFail++ }
            }
        }
    }

    $snapshot.generated = (Get-Date).ToString('o')
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
    $phoneInv = Get-PhoneInventory

    # Map phone -> PC destinations
    $mapped = @()
    $ambiguousThemes = @()

    foreach ($k in $phoneInv.Keys) {
        $root = ($k -split '\\')[0]
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

        $pcPath = Get-PcPathFromPhoneRelative -DiskRoot $disk -PhoneRelative $k
        if (-not $pcPath) { continue }

        $mapped += [pscustomobject]@{
            PhoneRelative = $k
            PhoneItem     = $phoneInv[$k].Item
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
    foreach ($m in $mapped) {
        if (-not (Test-Path -LiteralPath $m.PcPath)) { $toCopy += $m }
    }

    Write-Host ""
    Write-Host "Phone files considered: $($mapped.Count)" -ForegroundColor Cyan
    Write-Host "Copy to PC (new): $($toCopy.Count)" -ForegroundColor Cyan

    $toDeletePc = @()
    if ($Mode -eq 'Phone2PCDelete') {
        # Build expected PC set from phone state
        $expectedPc = @{}
        foreach ($m in $mapped) { $expectedPc[$m.PcPath] = $true }

        # Scan current PC Mobile selection (in-scope) and delete those missing on phone
        $pcSelection = Build-PcMobileSelection -Disks $connectedDisks -ScanRoots $ScanRoots
        foreach ($rel in $pcSelection.Keys) {
            $pcPath = $pcSelection[$rel].PcPath
            if (-not $expectedPc.ContainsKey($pcPath)) {
                $toDeletePc += $pcSelection[$rel]
            }
        }
        Write-Host "Delete on PC: $($toDeletePc.Count)" -ForegroundColor Yellow
        if ($toDeletePc.Count -gt $MaxDeletes) {
            Write-Fail "[ERROR] Too many deletes ($($toDeletePc.Count) > $MaxDeletes). Refusing."
            exit 1
        }
    }

    Log "PLAN CopyToPC=$($toCopy.Count) DeleteOnPC=$($toDeletePc.Count)"

    if ($IsPreview) {
        Write-Warn "`n[PREVIEW] No changes made. Re-run with -Execute to apply."
        exit 0
    }

    if ($requireConfirmation) {
        Write-Host ""
        $ans = Read-Host "Proceed with EXECUTE? Type YES to continue"
        if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
        if ($Mode -eq 'Phone2PCDelete') {
            $ans2 = Read-Host "This mode can DELETE from PC. Type DELETE to continue"
            if ($ans2 -ne 'DELETE') { Write-Warn "Cancelled."; exit 0 }
        }
    }

    # Execute copy Phone -> PC
    $ok = 0
    $fail = 0
    $i = 0
    foreach ($m in $toCopy) {
        $i++
        $destDir = Split-Path -Path $m.PcPath -Parent
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null

        Write-Host "[$i/$($toCopy.Count)] COPY phone -> $($m.PcPath)" -ForegroundColor Cyan
        Log "COPY_PHONE $($m.PhoneRelative) -> $($m.PcPath)"

        $copied = Copy-MtpItemToPC -MtpItem $m.PhoneItem -DestDir $destDir
        if ($copied) { $ok++; Write-Ok "  [OK]" } else { $fail++; Write-Fail "  [FAIL]" }
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
                if ((Split-Path -Path $p -Leaf) -ieq 'Mobile') { $p; break }
                $p = Split-Path -Path $p -Parent
            }
        } | Select-Object -Unique

        foreach ($mf in $mobileFolders) {
            try {
                $left = Get-ChildItem -LiteralPath $mf -Recurse -File -ErrorAction SilentlyContinue
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
    if ($Mode -eq 'Phone2PCDelete') {
        Write-Host "  Deleted on PC: $delOk OK, $delFail FAIL"
    }
    Write-Host "Log: $logPath" -ForegroundColor Gray
    exit 0
}

Write-Fail "[ERROR] Unhandled mode: $Mode"
exit 1
