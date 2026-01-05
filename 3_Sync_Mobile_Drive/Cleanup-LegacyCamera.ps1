# ============================================================================
# Script Name: Cleanup-LegacyCamera.ps1
# Project: Media Archive Management - Mobile Sync (Pixel 8)
# Purpose:
#   One-time cleanup: remove ONLY the files previously copied to DCIM\Camera
#   by the old "Gallery -> DCIM\\Camera" sync implementation.
#
# Safety model:
#   - Builds the delete list ONLY from historical sync logs lines:
#       "COPY [GALLERY] ... -> <filename>"
#       "REPLACE [GALLERY] ... -> <filename>"
#   - Deletes ONLY matching filenames under legacyCameraPath.
#   - Default is PREVIEW; use -Execute to apply.
# ============================================================================

param(
    [string]$ConfigPath = "$PSScriptRoot\\device_config.json",
    [string]$LogDir = "$PSScriptRoot\\Logs",
    [int]$SinceDays = 0,

    [switch]$WhatIf,
    [switch]$Execute,
    [switch]$Yes,
    [switch]$Force,

    [int]$MaxDeletes = 2000
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

function Get-ParentPhonePath([string]$BasePath) {
    if ([string]::IsNullOrWhiteSpace($BasePath)) { return $null }
    $p = $BasePath.Trim().TrimEnd('\')
    $idx = $p.LastIndexOf('\')
    if ($idx -lt 0) { return $null }
    return $p.Substring(0, $idx)
}

$legacyCameraPath = ''
if ($config.phone.legacyCameraPath) { $legacyCameraPath = [string]$config.phone.legacyCameraPath }
elseif ($config.phone.galleryBasePath) { $legacyCameraPath = [string]$config.phone.galleryBasePath } # backward compat

if ([string]::IsNullOrWhiteSpace($legacyCameraPath)) {
    $phoneBasePath = [string]$config.phone.basePath
    $storageRoot = Get-ParentPhonePath -BasePath $phoneBasePath
    if ($storageRoot) {
        $leaf = ($storageRoot -split '\\' | Select-Object -Last 1)
        if ($leaf -ieq 'DCIM') { $storageRoot = Get-ParentPhonePath -BasePath $storageRoot }
    }
    if ($storageRoot) { $legacyCameraPath = "$storageRoot\\DCIM\\Camera" }
}

if ([string]::IsNullOrWhiteSpace($legacyCameraPath)) {
    Write-Fail "[ERROR] Cannot determine legacyCameraPath from config."
    exit 1
}

if (-not (Test-Path -LiteralPath $LogDir)) {
    Write-Fail "[ERROR] LogDir not found: $LogDir"
    exit 1
}

$logFiles = Get-ChildItem -LiteralPath $LogDir -File -Filter '*.log' -ErrorAction SilentlyContinue
if ($SinceDays -gt 0) {
    $cut = (Get-Date).AddDays(-1 * $SinceDays)
    $logFiles = $logFiles | Where-Object { $_.LastWriteTime -ge $cut }
}

if (-not $logFiles -or $logFiles.Count -eq 0) {
    Write-Warn "[WARN] No log files found in: $LogDir"
    exit 0
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CLEANUP LEGACY CAMERA (Pixel 8)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Config: $ConfigPath"
Write-Host "LegacyCameraPath: $legacyCameraPath"
Write-Host "LogDir: $LogDir"
Write-Host "Mode: $(if ($IsPreview) { 'PREVIEW' } else { 'EXECUTE' })"
if ($SinceDays -gt 0) { Write-Host "SinceDays: $SinceDays" -ForegroundColor Gray }
Write-Host ""

$names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

$re = [regex]'^\d{2}:\d{2}:\d{2}\s+(COPY|REPLACE)\s+\[GALLERY\]\s+.*->\s*(?<name>.+?)\s*$'
foreach ($lf in $logFiles) {
    try {
        foreach ($line in (Get-Content -LiteralPath $lf.FullName -ErrorAction SilentlyContinue)) {
            if (-not $line) { continue }
            $m = $re.Match($line)
            if (-not $m.Success) { continue }
            $n = [string]$m.Groups['name'].Value
            $n = $n.Trim()
            if ([string]::IsNullOrWhiteSpace($n)) { continue }
            if ($n -match '[\\/]') { continue } # camera was flat; any path here is suspicious
            $null = $names.Add($n)
        }
    } catch {}
}

if ($names.Count -eq 0) {
    Write-Warn "[WARN] No legacy Camera filenames found in logs (no 'COPY/REPLACE [GALLERY]' lines)."
    exit 0
}

Write-Host "Gallery files found in logs: $($names.Count)" -ForegroundColor Cyan

function Get-ShellApp {
    if (-not $script:ShellApp) { $script:ShellApp = New-Object -ComObject Shell.Application }
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

function Get-PhoneFolderFromPath {
    param([string]$Path)
    $segments = ($Path -split '\\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($segments.Count -gt 0 -and ($segments[0] -ieq 'PC' -or $segments[0] -ieq 'Questo PC' -or $segments[0] -ieq 'This PC')) {
        $segments = $segments | Select-Object -Skip 1
    }
    return Get-ShellFolderFromSegments -Segments $segments
}

function Try-GetMtpExtendedProperty {
    param($Item, [string]$Key)
    if (-not $Item -or [string]::IsNullOrWhiteSpace($Key)) { return $null }
    try { return $Item.ExtendedProperty($Key) } catch { return $null }
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
            $fileName = $null
            try { $fileName = [string](Try-GetMtpExtendedProperty -Item $it -Key 'System.FileName') } catch { $fileName = $null }
            if ([string]::IsNullOrWhiteSpace($fileName)) { $fileName = [string]$it.Name }
            if ($fileName -and ($fileName -ieq $Name)) { return $it }
        }
    } catch {}

    return $null
}

function Remove-MtpFile {
    param($ParentFolder, [string]$FileName)
    $it = Find-MtpItemByName -Folder $ParentFolder -Name $FileName
    if (-not $it) { return $false }
    try { $it.InvokeVerb('Delete'); return $true } catch { return $false }
}

$cameraFolder = $null
try { $cameraFolder = Get-PhoneFolderFromPath -Path $legacyCameraPath } catch { $cameraFolder = $null }
if (-not $cameraFolder) {
    Write-Fail "[ERROR] Cannot access phone folder via Shell: $legacyCameraPath"
    Write-Warn "Ensure Pixel 8 is connected and unlocked."
    exit 1
}
Write-Ok "[OK] Phone path reachable: $legacyCameraPath"

$existing = @()
$missing = 0
foreach ($n in ($names | Sort-Object)) {
    $it = Find-MtpItemByName -Folder $cameraFolder -Name $n
    if ($it) { $existing += $n } else { $missing++ }
}

Write-Host ""
Write-Host "Plan:" -ForegroundColor Cyan
Write-Host "  Delete from Camera: $($existing.Count)" -ForegroundColor Yellow
Write-Host "  Missing on phone  : $missing" -ForegroundColor Gray
if ($existing.Count -gt 0) {
    $show = $existing | Select-Object -First 25
    Write-Host "  Examples (first $($show.Count)):" -ForegroundColor Gray
    foreach ($s in $show) { Write-Host "    - $s" -ForegroundColor Gray }
}

if ($existing.Count -gt $MaxDeletes) {
    Write-Fail "[ERROR] Too many deletes ($($existing.Count) > $MaxDeletes). Refusing."
    exit 1
}

if ($existing.Count -eq 0) {
    Write-Ok "[OK] Nothing to delete."
    exit 0
}

$runId = Get-Date -Format 'yyyyMMdd_HHmmss'
$cleanupLog = Join-Path $LogDir "CLEANUP_LEGACY_CAMERA_${runId}.log"
function Log([string]$Line) {
    $ts = Get-Date -Format 'HH:mm:ss'
    "$ts  $Line" | Out-File -FilePath $cleanupLog -Encoding UTF8 -Append
}

Log "START Preview=$IsPreview LegacyCameraPath=$legacyCameraPath LogDir=$LogDir SinceDays=$SinceDays"
Log "PLAN Delete=$($existing.Count) Missing=$missing"
foreach ($n in $existing) { Log "TARGET $n" }

if ($IsPreview) {
    Write-Warn "`n[PREVIEW] No changes made. Re-run with -Execute to apply."
    Write-Host "Log: $cleanupLog" -ForegroundColor Gray
    exit 0
}

if (-not $Yes) {
    Write-Host ""
    $ans = Read-Host "Proceed to DELETE $($existing.Count) file(s) from legacy Camera? Type YES to continue"
    if ($ans -ne 'YES') { Write-Warn "Cancelled."; exit 0 }
    if (-not $Force) {
        $ans2 = Read-Host "This is destructive on the phone. Type DELETE to continue"
        if ($ans2 -ne 'DELETE') { Write-Warn "Cancelled."; exit 0 }
    }
}

$ok = 0
$fail = 0
$i = 0
foreach ($n in $existing) {
    $i++
    Write-Host "[$i/$($existing.Count)] DELETE phone Camera -> $n" -ForegroundColor Yellow
    Log "DELETE_PHONE_CAMERA $n"
    $res = Remove-MtpFile -ParentFolder $cameraFolder -FileName $n
    if ($res) { $ok++ } else { $fail++ }
}

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Deleted: $ok OK, $fail FAIL"
Write-Host "Log: $cleanupLog" -ForegroundColor Gray
exit 0
