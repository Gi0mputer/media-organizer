# ============================================================================
# NOME: Check-ExternalDrive-ForiPhone.ps1
# DESCRIZIONE: Verifica se un disco esterno e' compatibile con iPhone (consiglio: exFAT)
#              e (opzionale) crea una struttura cartelle "navetta" per:
#                - Files (privato/pesante): _IPHONE_FILES
#                - Import verso Foto: _IPHONE_PHOTOS_IMPORT
#
# USO (Preview di default):
#   .\Check-ExternalDrive-ForiPhone.ps1 -DriveLetters X
#   .\Check-ExternalDrive-ForiPhone.ps1 -AllRemovable
#
# Creazione cartelle (richiede -Execute):
#   .\Check-ExternalDrive-ForiPhone.ps1 -DriveLetters X -CreateFolders -Execute
# ============================================================================

param(
    [string[]]$DriveLetters = @(),
    [switch]$AllRemovable,

    [switch]$CreateFolders,
    [string]$FilesFolderName = "_IPHONE_FILES",
    [string]$PhotosImportFolderName = "_IPHONE_PHOTOS_IMPORT",

    [switch]$WhatIf,
    [switch]$Execute,
    [switch]$Yes
)

$ErrorActionPreference = 'SilentlyContinue'

$IsPreview = $WhatIf -or (-not $Execute)

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Gray }
function Write-Ok([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Fail([string]$Message) { Write-Host $Message -ForegroundColor Red }

function Normalize-DriveLetter {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    $v = $Value.Trim()
    if ($v.EndsWith(':')) { $v = $v.TrimEnd(':') }
    if ($v.EndsWith('\')) { $v = $v.TrimEnd('\') }
    if ($v.Length -eq 0) { return $null }
    return $v.Substring(0, 1).ToUpperInvariant()
}

function Get-VolumeInfo {
    param([string]$Letter)

    $vol = $null
    try { $vol = Get-Volume -DriveLetter $Letter -ErrorAction Stop } catch { $vol = $null }

    if ($vol) {
        return [pscustomobject]@{
            DriveLetter = $Letter
            FileSystem = $vol.FileSystem
            DriveType = $vol.DriveType
            Label = $vol.FileSystemLabel
            Size = $vol.Size
            SizeRemaining = $vol.SizeRemaining
            HealthStatus = $vol.HealthStatus
            OperationalStatus = ($vol.OperationalStatus -join ',')
        }
    }

    $ld = $null
    try {
        $ld = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='{0}:'" -f $Letter) -ErrorAction Stop
    } catch { $ld = $null }

    if ($ld) {
        $driveTypeMap = @{
            0 = 'Unknown'
            1 = 'NoRootDirectory'
            2 = 'Removable'
            3 = 'Fixed'
            4 = 'Network'
            5 = 'CDROM'
            6 = 'RAMDisk'
        }
        $dt = $driveTypeMap[[int]$ld.DriveType]
        return [pscustomobject]@{
            DriveLetter = $Letter
            FileSystem = $ld.FileSystem
            DriveType = $dt
            Label = $ld.VolumeName
            Size = [int64]$ld.Size
            SizeRemaining = [int64]$ld.FreeSpace
            HealthStatus = ''
            OperationalStatus = ''
        }
    }

    return $null
}

function Get-IphoneCompatibilityNote {
    param([string]$FileSystem)
    if ([string]::IsNullOrWhiteSpace($FileSystem)) { return "UNKNOWN (disco non formattato o non leggibile da Windows)" }

    switch ($FileSystem.ToUpperInvariant()) {
        'EXFAT' { return 'OK (consigliato)' }
        'FAT32' { return 'OK (ma limite 4GB per file!)' }
        'FAT'   { return 'OK (ma limite 4GB per file!)' }
        'NTFS'  { return 'NO (in genere non supportato / non scrivibile su iPhone)' }
        default { return "CHECK (filesystem: $FileSystem)" }
    }
}

function Format-Bytes {
    param([int64]$Value)
    if ($Value -lt 0) { return '' }
    if ($Value -ge 1TB) { return ("{0:N1} TB" -f ($Value / 1TB)) }
    if ($Value -ge 1GB) { return ("{0:N1} GB" -f ($Value / 1GB)) }
    if ($Value -ge 1MB) { return ("{0:N1} MB" -f ($Value / 1MB)) }
    if ($Value -ge 1KB) { return ("{0:N1} KB" -f ($Value / 1KB)) }
    return ("{0} B" -f $Value)
}

function Get-DiskPartitionDetails {
    param([string]$DriveLetter)

    $part = $null
    $disk = $null
    $partitionCount = $null

    try { $part = Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop | Select-Object -First 1 } catch { $part = $null }
    if ($part) {
        try { $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop } catch { $disk = $null }
        try { $partitionCount = (Get-Partition -DiskNumber $part.DiskNumber -ErrorAction SilentlyContinue | Measure-Object).Count } catch { $partitionCount = $null }
    }

    return [pscustomobject]@{
        Partition = $part
        Disk = $disk
        PartitionCount = $partitionCount
    }
}

function Get-BitLockerInfo {
    param([string]$DriveLetter)
    $mp = "{0}:" -f $DriveLetter
    try {
        $b = Get-BitLockerVolume -MountPoint $mp -ErrorAction Stop
        if ($b) {
            return [pscustomobject]@{
                VolumeStatus = $b.VolumeStatus
                ProtectionStatus = $b.ProtectionStatus
                EncryptionMethod = $b.EncryptionMethod
            }
        }
    } catch {}
    return $null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CHECK EXTERNAL DRIVE FOR IPHONE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor Gray
Write-Host ""

$targets = @()

if ($AllRemovable) {
    try {
        $rem = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Removable' }
        foreach ($v in $rem) { $targets += $v.DriveLetter.ToString().ToUpperInvariant() }
    } catch {
        Write-Warn "[WARN] Get-Volume failed; -AllRemovable may be incomplete."
    }
}

foreach ($d in $DriveLetters) {
    if ([string]::IsNullOrWhiteSpace($d)) { continue }

    # Support common input formats:
    # - -DriveLetters D E
    # - -DriveLetters D,E
    # - -DriveLetters "D,E"
    $parts = @()
    if ($d -match '[,;]') { $parts = $d -split '[,;]' } else { $parts = @($d) }

    foreach ($p in $parts) {
        $n = Normalize-DriveLetter -Value $p
        if ($n) { $targets += $n }
    }
}

$targets = $targets | Sort-Object -Unique

if (-not $targets -or $targets.Count -eq 0) {
    Write-Fail "[ERROR] No drives specified."
    Write-Host "Use one of:" -ForegroundColor Yellow
    Write-Host "  -DriveLetters X" -ForegroundColor Gray
    Write-Host "  -AllRemovable" -ForegroundColor Gray
    exit 1
}

# Report file
$logDir = Join-Path $PSScriptRoot 'Logs'
try { New-Item -ItemType Directory -Path $logDir -Force | Out-Null } catch {}
$reportPath = Join-Path $logDir ("EXTERNAL_DRIVE_IPHONE_REPORT_{0}.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$report = @()
$report += "# External Drive Check - iPhone Compatibility"
$report += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
$report += ""

if (-not $IsPreview -and $CreateFolders -and -not $Yes) {
    $ans = Read-Host "Type YES to create folders on: $($targets -join ', ')"
    if ($ans -ne 'YES') {
        Write-Warn "Cancelled."
        exit 0
    }
}

foreach ($letter in $targets) {
    $mount = "{0}:\\" -f $letter

    if (-not (Test-Path -LiteralPath $mount)) {
        Write-Warn "[SKIP] Drive not found: $mount"
        $report += "## $mount"
        $report += "- Status: NOT FOUND"
        $report += ""
        continue
    }

    $info = Get-VolumeInfo -Letter $letter
    if (-not $info) {
        Write-Warn "[SKIP] Could not read volume info: $mount"
        $report += "## $mount"
        $report += "- Status: UNKNOWN (no volume info)"
        $report += ""
        continue
    }

    $compat = Get-IphoneCompatibilityNote -FileSystem $info.FileSystem
    $size = Format-Bytes -Value ([int64]$info.Size)
    $free = Format-Bytes -Value ([int64]$info.SizeRemaining)

    $dp = Get-DiskPartitionDetails -DriveLetter $letter
    $disk = $dp.Disk
    $part = $dp.Partition
    $bitlocker = Get-BitLockerInfo -DriveLetter $letter

    Write-Host "Drive $mount" -ForegroundColor Cyan
    Write-Host "  Label: $($info.Label)" -ForegroundColor Gray
    Write-Host "  Type: $($info.DriveType)" -ForegroundColor Gray
    Write-Host "  FS: $($info.FileSystem)  ->  $compat" -ForegroundColor White
    if ($disk) {
        Write-Host "  Disk: $($disk.FriendlyName)  Bus: $($disk.BusType)  PartitionStyle: $($disk.PartitionStyle)" -ForegroundColor Gray
        Write-Host "  Sectors: Logical $($disk.LogicalSectorSize)  Physical $($disk.PhysicalSectorSize)" -ForegroundColor Gray
    }
    if ($dp.PartitionCount -ne $null) {
        Write-Host "  Partitions: $($dp.PartitionCount)" -ForegroundColor Gray
    }
    if ($disk -and $disk.PartitionStyle -eq 'MBR' -and $part -and $part.MbrType -ne $null) {
        Write-Host "  MBR Type: $($part.MbrType)" -ForegroundColor Gray
        if ($info.FileSystem -and $info.FileSystem.ToUpperInvariant() -eq 'EXFAT' -and $part.MbrType -ne 7) {
            Write-Warn "  [WARN] MBR type != 7 ma filesystem = exFAT. Su Mac/iPhone puo' non montare."
            Write-Warn "         Fix: usa `3_Sync_Mobile_Drive/Fix-MbrPartitionType-ForExFAT.ps1` (richiede admin)."
        }
    }
    if ($bitlocker) {
        Write-Warn "  [WARN] BitLocker detected: iPhone non monta dischi cifrati."
    }
    Write-Host "  Size: $size   Free: $free" -ForegroundColor Gray

    if ($info.FileSystem -and $info.FileSystem.ToUpperInvariant() -eq 'NTFS') {
        Write-Warn "  [WARN] iPhone di solito non gestisce NTFS: usa exFAT per la navetta."
    }
    if ($info.FileSystem -and ($info.FileSystem.ToUpperInvariant() -eq 'FAT32' -or $info.FileSystem.ToUpperInvariant() -eq 'FAT')) {
        Write-Warn "  [WARN] FAT32/FAT ha limite 4GB per file (video lunghi = problema)."
    }

    $report += "## $mount"
    $report += "- Label: $($info.Label)"
    $report += "- DriveType: $($info.DriveType)"
    $report += "- FileSystem: $($info.FileSystem)"
    $report += "- Compatibility: $compat"
    if ($disk) {
        $report += "- Disk: $($disk.FriendlyName)"
        $report += "- BusType: $($disk.BusType)"
        $report += "- PartitionStyle: $($disk.PartitionStyle)"
        $report += "- LogicalSectorSize: $($disk.LogicalSectorSize)"
        $report += "- PhysicalSectorSize: $($disk.PhysicalSectorSize)"
    }
    if ($dp.PartitionCount -ne $null) { $report += "- PartitionCount: $($dp.PartitionCount)" }
    if ($disk -and $disk.PartitionStyle -eq 'MBR' -and $part -and $part.MbrType -ne $null) {
        $report += "- MbrType: $($part.MbrType)"
        if ($info.FileSystem -and $info.FileSystem.ToUpperInvariant() -eq 'EXFAT' -and $part.MbrType -ne 7) {
            $report += "- WARN: MBR type != 7 but filesystem = exFAT (Apple devices may not mount)"
        }
    }
    if ($bitlocker) {
        $report += "- BitLocker: YES ($($bitlocker.VolumeStatus), $($bitlocker.ProtectionStatus), $($bitlocker.EncryptionMethod))"
    }
    $report += "- Size: $size"
    $report += "- Free: $free"

    if ($CreateFolders) {
        $filesRoot = Join-Path $mount $FilesFolderName
        $photosRoot = Join-Path $mount $PhotosImportFolderName

        if ($IsPreview) {
            Write-Info "  [PREVIEW] Create: $filesRoot"
            Write-Info "  [PREVIEW] Create: $photosRoot"
            $report += "- CreateFolders: PREVIEW"
            $report += "  - $filesRoot"
            $report += "  - $photosRoot"
        }
        else {
            try { New-Item -ItemType Directory -Path $filesRoot -Force | Out-Null } catch {}
            try { New-Item -ItemType Directory -Path $photosRoot -Force | Out-Null } catch {}
            Write-Ok "  [OK] Folders ensured: $FilesFolderName, $PhotosImportFolderName"
            $report += "- CreateFolders: OK"
            $report += "  - $filesRoot"
            $report += "  - $photosRoot"
        }
    }

    if ($info.FileSystem -and $info.FileSystem.ToUpperInvariant() -ne 'EXFAT') {
        $report += "- Suggested: format as exFAT (DESTRUCTIVE)"
        $report += "  - Example: Format-Volume -DriveLetter $letter -FileSystem exFAT -NewFileSystemLabel 'IPHONE_SHUTTLE'"
    }

    $report += ""
    Write-Host ""
}

$report | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "Report: $reportPath" -ForegroundColor Gray

Write-Host ""
Write-Host "Note:" -ForegroundColor Yellow
Write-Host "- La formattazione cancella tutti i dati: fai backup prima." -ForegroundColor Gray
Write-Host "- Per iPhone, exFAT e' la scelta piu' semplice per SSD esterni." -ForegroundColor Gray
