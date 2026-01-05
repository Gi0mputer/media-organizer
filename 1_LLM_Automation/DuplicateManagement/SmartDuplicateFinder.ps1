param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [switch]$Delete = $false,

    [switch]$PermanentDelete = $false,

    [switch]$Force = $false,

    [string]$LogFile = ""
)

$analysisDir = Join-Path (Split-Path $PSScriptRoot -Parent) "Analysis"
if (-not (Test-Path -LiteralPath $analysisDir)) {
    New-Item -Path $analysisDir -ItemType Directory -Force | Out-Null
}
if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $LogFile = Join-Path $analysisDir ("DUPLICATE_REPORT_{0}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}

# Configuration
$VideoExts = @('.mp4', '.mov', '.avi', '.mkv', '.m4v')
$PhotoExts = @('.jpg', '.jpeg', '.png', '.heic')
$WhatsAppPatterns = @("*WhatsApp*", "*WA????*", "VID-*WA*", "IMG-*WA*")

function Remove-FileSafe {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    if ($PermanentDelete) {
        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            return $true
        }
        catch {
            return $false
        }
    }

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

function Get-VideoDuration {
    param($Path)
    try {
        $duration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$Path" 2>$null
        return [double]$duration
    }
    catch {
        return 0
    }
}

function Is-WhatsApp {
    param($FileName)
    foreach ($pattern in $WhatsAppPatterns) {
        if ($FileName -like $pattern) { return $true }
    }
    return $false
}

Write-Host "=== SMART DUPLICATE FINDER ===" -ForegroundColor Cyan
Write-Host "Source: $SourcePath"
Write-Host "Delete Mode: $($Delete)"
if ($Delete) {
    $modeLabel = if ($PermanentDelete) { "PERMANENT DELETE" } else { "RECYCLE BIN (preferred)" }
    Write-Host "Delete Strategy: $modeLabel" -ForegroundColor Yellow
}
Write-Host "Log: $LogFile"
Write-Host ""

if ($Delete -and (-not $Force)) {
    Write-Host "WARNING: You are about to delete files." -ForegroundColor Red
    if (-not $PermanentDelete) {
        Write-Host "Files will be moved to Recycle Bin (space is freed only after emptying it)." -ForegroundColor Yellow
    }
    $ans = Read-Host "Type YES to proceed"
    if ($ans -ne 'YES') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

$report = @()
$report += "=== DUPLICATE REPORT - $(Get-Date) ==="
$report += "Source: $SourcePath"
$report += "Delete Mode: $($Delete)"
$report += "Delete Strategy: $(if (-not $Delete) { 'N/A' } elseif ($PermanentDelete) { 'Permanent' } else { 'RecycleBin' })"
$report += ""

# 1. EXACT DUPLICATES (HASH BASED)
Write-Host "Phase 1: Scanning for EXACT duplicates (Hash)..." -ForegroundColor Yellow
$files = Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue
$count = $files.Count
Write-Host "  Found $count files. Grouping by size..."

$sizeGroups = $files | Group-Object Length | Where-Object { $_.Count -gt 1 }
Write-Host "  Found $($sizeGroups.Count) groups with same size. Calculating hashes..."

$exactDupesCount = 0
$spaceSavings = 0
$deleteErrors = 0

foreach ($group in $sizeGroups) {
    $hashGroup = $group.Group | Get-FileHash -Algorithm SHA256 | Group-Object Hash | Where-Object { $_.Count -gt 1 }
    
    foreach ($hash in $hashGroup) {
        $dupes = $hash.Group | Select-Object @{N = 'File'; E = { $_.Path } }, @{N = 'Info'; E = { Get-Item $_.Path } }
        
        # Strategy: Keep the one that is NOT WhatsApp, or the Oldest, or Shortest Path
        $sorted = $dupes | Sort-Object `
        @{E = { Is-WhatsApp $_.Info.Name }; Ascending = $true }, ` # Prefer Non-WhatsApp (False < True)
        @{E = { $_.Info.CreationTime }; Ascending = $true }, `      # Prefer Older
        @{E = { $_.File.Length }; Ascending = $true }               # Prefer Shortest Path
            
        $keep = $sorted[0]
        $deleteList = $sorted | Select-Object -Skip 1
        
        $report += "EXACT MATCH DETECTED:"
        $report += "  KEEP: $($keep.File) (Created: $($keep.Info.CreationTime))"
        
        foreach ($del in $deleteList) {
            $report += "  DELETE: $($del.File) (Created: $($del.Info.CreationTime))"
            $report += "    [Reason: Identical content to kept file]"
            $exactDupesCount++
            $spaceSavings += $del.Info.Length
            
            if ($Delete) {
                Write-Host "  Deleting: $($del.File)" -ForegroundColor Red
                if (-not (Remove-FileSafe -Path $del.File)) {
                    $deleteErrors++
                    Write-Host "    [FAIL] Could not delete (check permissions / Recycle Bin)." -ForegroundColor Yellow
                }
            }
        }
        $report += ""
    }
}

# 2. WHATSAPP FUZZY MATCH (VIDEO DURATION)
Write-Host "Phase 2: Scanning for WHATSAPP duplicates (Duration)..." -ForegroundColor Yellow
$videos = $files | Where-Object { $VideoExts -contains $_.Extension.ToLower() }
Write-Host "  Analyzing $($videos.Count) videos..."

# Optimization: Only check videos that have a "WhatsApp" counterpart in the same folder or subfolders
# Actually, let's group by Duration (rounded to 2 decimal places)
# This is slow, so we do it carefully.

$videoData = @()
$counter = 0
foreach ($vid in $videos) {
    $counter++
    if ($counter % 100 -eq 0) { Write-Progress -Activity "Getting Durations" -Status "$counter / $($videos.Count)" -PercentComplete (($counter / $videos.Count) * 100) }
    
    $dur = Get-VideoDuration -Path $vid.FullName
    if ($dur -gt 0) {
        $videoData += [PSCustomObject]@{
            File     = $vid
            Duration = [math]::Round($dur, 2)
            IsWA     = Is-WhatsApp $vid.Name
        }
    }
}

$durGroups = $videoData | Group-Object Duration | Where-Object { $_.Count -gt 1 }

foreach ($group in $durGroups) {
    # We have videos with same duration.
    # Check if we have a mix of WhatsApp and Non-WhatsApp
    $waFiles = $group.Group | Where-Object { $_.IsWA }
    $origFiles = $group.Group | Where-Object { -not $_.IsWA }
    
    if ($waFiles.Count -gt 0 -and $origFiles.Count -gt 0) {
        # Potential match!
        foreach ($wa in $waFiles) {
            # Find an original that is larger (WhatsApp compresses)
            $betterOriginal = $origFiles | Where-Object { $_.File.Length -gt $wa.File.Length } | Sort-Object -Property @{E = { $_.File.Length }; Ascending = $false } | Select-Object -First 1
            
            if ($betterOriginal) {
                $report += "WHATSAPP DUPLICATE DETECTED (Duration Match: $($group.Name)s):"
                $report += "  KEEP (Original): $($betterOriginal.File.FullName) ($([math]::Round($betterOriginal.File.Length/1MB, 2)) MB)"
                $report += "  DELETE (WhatsApp): $($wa.File.FullName) ($([math]::Round($wa.File.Length/1MB, 2)) MB)"
                $report += "    [Reason: WhatsApp version of existing original]"
                
                $exactDupesCount++
                $spaceSavings += $wa.File.Length
                
                if ($Delete) {
                    Write-Host "  Deleting WA: $($wa.File.FullName)" -ForegroundColor Red
                    if (-not (Remove-FileSafe -Path $wa.File.FullName)) {
                        $deleteErrors++
                        Write-Host "    [FAIL] Could not delete (check permissions / Recycle Bin)." -ForegroundColor Yellow
                    }
                }
                $report += ""
            }
        }
    }
}

$savedMB = [math]::Round($spaceSavings / 1MB, 2)
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Green
Write-Host "Duplicates found: $exactDupesCount"
Write-Host "Potential space savings: $savedMB MB"
if ($Delete) {
    Write-Host "Delete errors: $deleteErrors" -ForegroundColor Yellow
}
Write-Host "Report saved to: $LogFile"

$report | Out-File -FilePath $LogFile -Encoding UTF8
