# ============================================================================
# UNIVERSAL VIDEO STANDARDIZER - Master Script
# ============================================================================
# Purpose: Standardize ANY video to 1080p 30fps H.264 for archive/merge
# Use case: Compress for storage + LosslessCut compatibility
# Method: Full GPU pipeline (NVENC) when available, CPU fallback
# ============================================================================

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

# Configuration
$TARGET_HEIGHT = 1080           # Max height (preserves aspect ratio)
$TARGET_FPS = 30                # Standard FPS
$VIDEO_CODEC = "libx264"        # H.264 for max compatibility
$VIDEO_PRESET = "medium"        # Balance speed/quality
$CRF = 23                       # Quality (lower = better, 18-28 range)
$AUDIO_CODEC = "aac"
$AUDIO_BITRATE = "128k"

# GPU Detection
$GPU_AVAILABLE = $false
try {
    $nvencTest = & ffmpeg -hide_banner -f lavfi -i nullsrc -c:v h264_nvenc -t 0.1 -f null - 2>&1
    if ($LASTEXITCODE -eq 0) {
        $GPU_AVAILABLE = $true
        $VIDEO_CODEC = "h264_nvenc"
        $VIDEO_PRESET = "p4"
    }
}
catch {}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  UNIVERSAL VIDEO STANDARDIZER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Target: 1080p 30fps H.264"
Write-Host "GPU Encoding: $(if ($GPU_AVAILABLE) { 'YES (NVENC)' } else { 'NO (CPU)' })`n"

# Extensions to process
$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.mpg', '.mpeg', '.wmv', '.flv', '.webm')

# Collect all video files
$allFiles = @()

foreach ($path in $Paths) {
    if (-not $path) { continue }
    
    $item = Get-Item $path -ErrorAction SilentlyContinue
    if (-not $item) { continue }
    
    if ($item.PSIsContainer) {
        Write-Host "[INFO] Scanning folder: $($item.Name)" -ForegroundColor Gray
        $folderFiles = Get-ChildItem $item.FullName -Recurse -File | Where-Object {
            $VIDEO_EXTENSIONS -contains $_.Extension.ToLower()
        }
        $allFiles += $folderFiles
    }
    else {
        if ($VIDEO_EXTENSIONS -contains $item.Extension.ToLower()) {
            $allFiles += $item
        }
    }
}

if ($allFiles.Count -eq 0) {
    Write-Host "[ERROR] No video files found!" -ForegroundColor Red
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "Found $($allFiles.Count) video file(s)`n" -ForegroundColor Green

$processedCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($file in $allFiles) {
    $index = $allFiles.IndexOf($file) + 1
    Write-Host "=========================================================================`n[$index/$($allFiles.Count)] Processing: $($file.Name)" -ForegroundColor Cyan
    
    # Skip if already standardized (check filename pattern)
    if ($file.Name -match '_STD\.(mp4|mov)$') {
        Write-Host "  [SKIP] Already standardized (has _STD suffix)" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    # Get video info
    try {
        $probeJson = & ffprobe -v quiet -print_format json -show_format -show_streams $file.FullName 2>$null | ConvertFrom-Json
        $videoStream = $probeJson.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
        $audioStream = $probeJson.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
        
        if (-not $videoStream) {
            Write-Host "  [ERROR] No video stream found!" -ForegroundColor Red
            $errorCount++
            continue
        }
        
        $width = [int]$videoStream.width
        $height = [int]$videoStream.height
        $codec = $videoStream.codec_name
        
        # Parse FPS
        $fps = 30
        if ($videoStream.r_frame_rate -match '(\d+)/(\d+)') {
            $fps = [math]::Round([int]$matches[1] / [int]$matches[2], 2)
        }
        
        Write-Host "  Current: ${width}x${height} ${fps}fps $codec" -ForegroundColor Gray
        
    }
    catch {
        Write-Host "  [ERROR] Failed to probe video: $_" -ForegroundColor Red
        $errorCount++
        continue
    }
    
    # Determine orientation and scaling
    $isPortrait = $height -gt $width
    $scale = ""
    
    if ($isPortrait) {
        # Portrait: scale to max height 1080
        if ($height -gt $TARGET_HEIGHT) {
            $newHeight = $TARGET_HEIGHT
            $newWidth = [math]::Floor($width * ($TARGET_HEIGHT / $height))
            $newWidth = $newWidth - ($newWidth % 2)  # Make even
            $scale = "${newWidth}:${newHeight}"
        }
    }
    else {
        # Landscape: scale to max height 1080 (width adjusts)
        if ($height -gt $TARGET_HEIGHT) {
            $newHeight = $TARGET_HEIGHT
            $newWidth = [math]::Floor($width * ($TARGET_HEIGHT / $height))
            $newWidth = $newWidth - ($newWidth % 2)
            $scale = "${newWidth}:${newHeight}"
        }
    }
    
    # Build output filename
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $outputFile = Join-Path $file.DirectoryName "${baseName}_STD.mp4"
    $tempFile = Join-Path $file.DirectoryName "${baseName}_TEMP.mp4"
    
    # Build ffmpeg command
    $ffmpegArgs = @(
        "-i", $file.FullName
        "-y"
    )
    
    # Video encoding
    if ($GPU_AVAILABLE) {
        $ffmpegArgs += "-c:v", $VIDEO_CODEC
        $ffmpegArgs += "-preset", $VIDEO_PRESET
        $ffmpegArgs += "-cq", "23"
    }
    else {
        $ffmpegArgs += "-c:v", $VIDEO_CODEC
        $ffmpegArgs += "-preset", $VIDEO_PRESET
        $ffmpegArgs += "-crf", "$CRF"
    }
    
    # Scaling if needed
    if ($scale) {
        $ffmpegArgs += "-vf", "scale=$scale"
        Write-Host "  → Scaling to: $scale" -ForegroundColor Gray
    }
    
    # FPS standardization
    $ffmpegArgs += "-r", "$TARGET_FPS"
    
    # Audio handling
    if ($audioStream) {
        $ffmpegArgs += "-c:a", $AUDIO_CODEC
        $ffmpegArgs += "-b:a", $AUDIO_BITRATE
    }
    else {
        $ffmpegArgs += "-an"
    }
    
    # Pixel format (for compatibility)
    $ffmpegArgs += "-pix_fmt", "yuv420p"
    
    # Metadata
    $ffmpegArgs += "-movflags", "use_metadata_tags"
    $ffmpegArgs += "-map_metadata", "0"
    
    # Output
    $ffmpegArgs += $tempFile
    
    Write-Host "  [ENCODING] Target: 1080p 30fps H.264..." -ForegroundColor Yellow
    
    # Execute ffmpeg
    try {
        & ffmpeg -hide_banner @ffmpegArgs 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
            $tempSize = (Get-Item $tempFile).Length
            if ($tempSize -gt 100KB) {
                # Success - replace original
                Move-Item $tempFile $outputFile -Force
                Write-Host "  [OK] Standardized: $($file.Name) → ${baseName}_STD.mp4" -ForegroundColor Green
                
                # Preserve timestamps
                $creationTime = $file.CreationTime
                $lastWriteTime = $file.LastWriteTime
                $output = Get-Item $outputFile
                $output.CreationTime = $creationTime
                $output.LastWriteTime = $lastWriteTime
                
                $processedCount++
            }
            else {
                Write-Host "  [ERROR] Output file too small (< 100KB), likely failed" -ForegroundColor Red
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                $errorCount++
            }
        }
        else {
            Write-Host "  [ERROR] Encoding failed!" -ForegroundColor Red
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $errorCount++
        }
        
    }
    catch {
        Write-Host "  [ERROR] Exception: $_" -ForegroundColor Red
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        $errorCount++
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Processed: $processedCount" -ForegroundColor Green
Write-Host "  Skipped: $skippedCount" -ForegroundColor Yellow
Write-Host "  Errors: $errorCount" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
