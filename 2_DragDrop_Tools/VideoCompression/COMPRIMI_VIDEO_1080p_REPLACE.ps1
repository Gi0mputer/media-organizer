# ============================================================================
# Script Name: COMPRIMI_VIDEO_1080p_REPLACE.ps1
# Description: Ultra-Fast GPU video compression to 1920px using HEVC NVENC.
#              Full GPU pipeline (Decode -> Scale -> Encode).
#              REPLACES ORIGINAL on success.
#              Supports: Multiple files, Folders, Mixed formats
# Usage: Drag and drop files/folders onto the .bat wrapper
# ============================================================================

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

$SUFFIX = " (small)"
$MAX_LONG = 1920
$CQ = 24
$PRESET = "p5"
$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.insv', '.mpg', '.mpeg', '.wmv', '.flv', '.webm')

if ($Paths.Count -eq 0) {
    Write-Host "Drag and drop video files or folders onto this script."
    Write-Host "WARNING: Original files will be DELETED after successful conversion!"
    Read-Host "Press Enter to exit"
    exit
}

# Expand paths (handle both files and folders)
$allFiles = @()
foreach ($path in $Paths) {
    $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
    if (-not $resolved) { continue }
    
    $item = Get-Item $resolved
    if ($item.PSIsContainer) {
        # It's a folder -> Find all video files recursively
        Write-Host "[INFO] Scanning folder: $($item.Name)"
        $videos = Get-ChildItem $item.FullName -Recurse -File | Where-Object { $VIDEO_EXTENSIONS -contains $_.Extension.ToLower() }
        $allFiles += $videos
    }
    else {
        # It's a file -> Check if it's a video
        if ($VIDEO_EXTENSIONS -contains $item.Extension.ToLower()) {
            $allFiles += $item
        }
        else {
            Write-Host "[SKIP] Not a video: $($item.Name)" -ForegroundColor Yellow
        }
    }
}

if ($allFiles.Count -eq 0) {
    Write-Host "`n[ERROR] No video files found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "`nFound $($allFiles.Count) video file(s) to process.`n"

$processedCount = 0
foreach ($file in $allFiles) {
    $SRC = $file.FullName
    $OUT = Join-Path $file.DirectoryName "$($file.BaseName)$SUFFIX$($file.Extension)"
    
    Write-Host "========================================================================="
    Write-Host "[$($processedCount + 1)/$($allFiles.Count)] Processing: $($file.Name)"
    
    # Skip if already compressed
    if ($file.Name -match [regex]::Escape($SUFFIX)) {
        Write-Host "[SKIP] Already compressed." -ForegroundColor Yellow
        continue
    }
    
    # Check for audio
    $hasAudio = $false
    $probe = & ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$SRC" 2>$null
    if ($probe) { $hasAudio = $true }
    
    if ($hasAudio) {
        Write-Host "  [INFO] Audio detected -> Converting to AAC"
        $audioArgs = @("-c:a", "aac", "-b:a", "128k")
    }
    else {
        Write-Host "  [INFO] No audio -> Video only"
        $audioArgs = @("-an")
    }
    
    # Get dimensions for scaling
    $dims = & ffprobe -v error -select_streams v:0 -show_entries stream=width, height -of csv=p=0 "$SRC" 2>$null
    if ($dims -match "(\d+),(\d+)") {
        $w = [int]$matches[1]
        $h = [int]$matches[2]
        
        if ($w -gt $h) {
            $scaleFilter = "scale_cuda=${MAX_LONG}:-2"
        }
        else {
            $scaleFilter = "scale_cuda=-2:${MAX_LONG}"
        }
    }
    else {
        $scaleFilter = "scale_cuda=${MAX_LONG}:-2"
    }
    
    # Get timestamp
    $ctime = $file.CreationTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    Write-Host "  [INFO] Encoding: FULL GPU (NVENC + CUDA)"
    
    # Build ffmpeg command
    $ffmpegArgs = @(
        "-y", "-hide_banner", "-loglevel", "warning", "-stats"
        "-hwaccel", "cuda", "-hwaccel_output_format", "cuda"
        "-i", "$SRC"
        "-vf", $scaleFilter
        "-c:v", "hevc_nvenc", "-cq", $CQ, "-preset", $PRESET
        "-tag:v", "hvc1"
    ) + $audioArgs + @(
        "-map_metadata", "0"
        "-metadata", "creation_time=$ctime"
        "-movflags", "+faststart"
        "$OUT"
    )
    
    & ffmpeg @ffmpegArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Conversion failed." -ForegroundColor Red
        if (Test-Path $OUT) { Remove-Item $OUT }
        continue
    }
    
    # Verify output
    if (Test-Path $OUT) {
        $outSize = (Get-Item $OUT).Length
        if ($outSize -lt 100KB) {
            Write-Host "  [ERROR] Output too small/corrupt." -ForegroundColor Red
            Remove-Item $OUT
            continue
        }
        
        Write-Host "  [OK] Success!" -ForegroundColor Green
        
        # Restore timestamps
        $outItem = Get-Item $OUT
        $outItem.CreationTime = $file.CreationTime
        $outItem.LastWriteTime = $file.LastWriteTime
        
        # DELETE ORIGINAL
        Remove-Item $SRC -Force
        Write-Host "  [INFO] Original deleted." -ForegroundColor Yellow
        $processedCount++
    }
    else {
        Write-Host "  [ERROR] Output not created." -ForegroundColor Red
    }
}

Write-Host "`n========================================================================="
Write-Host "Completed: $processedCount / $($allFiles.Count) files processed successfully." -ForegroundColor Cyan
Read-Host "Press Enter to exit"
