# ============================================================================
# NOME: Fix-MbrPartitionType-ForExFAT.ps1
# DESCRIZIONE: Fix non distruttivo per casi in cui il filesystem e' exFAT ma la
#              partizione MBR e' marcata come FAT32 (MbrType=0x0C/12) o altro.
#              Alcuni dispositivi Apple possono rifiutare il mount in questo caso.
#
# COSA FA:
# - Verifica: Disk PartitionStyle = MBR, Volume FileSystem = exFAT
# - Se MbrType != 7, propone di settarlo a 7 (0x07) via Set-Partition
#
# SICUREZZA:
# - Preview di default
# - Richiede admin in Execute
#
# USO:
#   .\Fix-MbrPartitionType-ForExFAT.ps1 -DriveLetters E
#   .\Fix-MbrPartitionType-ForExFAT.ps1 -DriveLetters E -Execute
# ============================================================================

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$DriveLetters,

    [uint16]$TargetMbrType = 7,

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
    if ($v -match '[,;]') { $v = ($v -split '[,;]')[0] }
    $v = $v.Trim()
    if ($v.EndsWith(':')) { $v = $v.TrimEnd(':') }
    if ($v.EndsWith('\')) { $v = $v.TrimEnd('\') }
    if ($v.Length -eq 0) { return $null }
    return $v.Substring(0, 1).ToUpperInvariant()
}

function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FIX MBR PARTITION TYPE FOR exFAT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })" -ForegroundColor Gray
Write-Host "Target MbrType: $TargetMbrType (0x$('{0:X2}' -f $TargetMbrType))" -ForegroundColor Gray
Write-Host ""

$targets = @()
foreach ($d in $DriveLetters) {
    if ([string]::IsNullOrWhiteSpace($d)) { continue }
    $parts = if ($d -match '[,;]') { $d -split '[,;]' } else { @($d) }
    foreach ($p in $parts) {
        $n = Normalize-DriveLetter -Value $p
        if ($n) { $targets += $n }
    }
}
$targets = $targets | Sort-Object -Unique

if (-not $targets -or $targets.Count -eq 0) {
    Write-Fail "[ERROR] No drives specified."
    exit 1
}

if (-not $IsPreview) {
    if (-not (Test-IsAdmin)) {
        Write-Fail "[ERROR] This operation requires Administrator privileges."
        Write-Host "Apri PowerShell come Admin e rilancia con -Execute." -ForegroundColor Yellow
        exit 1
    }

    if (-not $Yes) {
        $ans = Read-Host "Type YES to set MBR type=$TargetMbrType on: $($targets -join ', ')"
        if ($ans -ne 'YES') {
            Write-Warn "Cancelled."
            exit 0
        }
    }
}

foreach ($letter in $targets) {
    $mount = "{0}:\\" -f $letter
    if (-not (Test-Path -LiteralPath $mount)) {
        Write-Warn "[SKIP] Drive not found: $mount"
        continue
    }

    $vol = $null
    try { $vol = Get-Volume -DriveLetter $letter -ErrorAction Stop } catch { $vol = $null }
    $part = $null
    try { $part = Get-Partition -DriveLetter $letter -ErrorAction Stop | Select-Object -First 1 } catch { $part = $null }
    $disk = $null
    if ($part) { try { $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop } catch { $disk = $null } }

    Write-Host "Drive $mount" -ForegroundColor Cyan
    if ($vol) { Write-Host "  FS: $($vol.FileSystem)  Label: $($vol.FileSystemLabel)" -ForegroundColor Gray }
    if ($disk) { Write-Host "  PartitionStyle: $($disk.PartitionStyle)  Disk: $($disk.FriendlyName)" -ForegroundColor Gray }
    if ($part -and $part.MbrType -ne $null) { Write-Host "  Current MbrType: $($part.MbrType)" -ForegroundColor Gray }

    if (-not $vol -or -not $part -or -not $disk) {
        Write-Warn "  [SKIP] Missing volume/partition/disk info."
        Write-Host ""
        continue
    }

    if ($disk.PartitionStyle -ne 'MBR') {
        Write-Info "  [OK] Not an MBR disk -> nothing to fix."
        Write-Host ""
        continue
    }

    if (-not $vol.FileSystem -or $vol.FileSystem.ToUpperInvariant() -ne 'EXFAT') {
        Write-Warn "  [SKIP] FileSystem is not exFAT."
        Write-Host ""
        continue
    }

    if ($part.MbrType -eq $TargetMbrType) {
        Write-Ok "  [OK] MbrType already correct."
        Write-Host ""
        continue
    }

    if ($IsPreview) {
        Write-Warn "  [PREVIEW] Would set MbrType: $($part.MbrType) -> $TargetMbrType"
        Write-Host ""
        continue
    }

    try {
        Set-Partition -DriveLetter $letter -MbrType $TargetMbrType -ErrorAction Stop | Out-Null
        Write-Ok "  [OK] MbrType updated."

        $part2 = Get-Partition -DriveLetter $letter -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($part2 -and $part2.MbrType -ne $null) {
            Write-Host "  New MbrType: $($part2.MbrType)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Fail "  [FAIL] Could not update MbrType (run as Admin?)."
    }

    Write-Host ""
}

Write-Host "Done." -ForegroundColor Cyan

