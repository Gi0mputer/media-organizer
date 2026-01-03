# ============================================================================
# VIDEO REPAIR - Automatic Fixer
# ============================================================================
# Purpose: Fix corrupted metadata, re-mux broken merges, standardize problem files
# Input: Drag & drop problematic videos or folders
# Output: Repaired videos with _FIXED suffix
# ============================================================================

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Paths
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VIDEO REPAIR TOOL" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$VIDEO_EXTENSIONS = @('.mp4', '.mov', '.avi', '.mkv', '.m4v')

# Collect files
$allFiles = @()

foreach ($path in $Paths) {
    if (-not $path) { continue }
    
    $item = Get-Item $path -ErrorAction SilentlyContinue
    if (-not $item) { continue }
    
    if ($item.PSIsContainer) {
        Write-Host "[SCANNING] $($item.Name)..." -ForegroundColor Gray
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
    Write-Host "[ERROR] No video files found!`n" -ForegroundColor Red
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "Found $($allFiles.Count) video(s) to repair`n" -ForegroundColor Green

$repairedCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($file in $allFiles) {
    $index = $allFiles.IndexOf($file) + 1
    Write-Host "========================================================================="
    Write-Host "[$index/$($allFiles.Count)] Repairing: $($file.Name)" -ForegroundColor Cyan
    
    # Skip if already fixed
    if ($file.Name -match '_FIXED\.(mp4|mov)$') {
        Write-Host "  [SKIP] Already repaired" -ForegroundColor Yellow
        $skippedCount++
        continue
    }
    
    # Analyze file
    try {
        $probeJson = & ffprobe -v quiet -print_format json -show_format -show_streams $file.FullName 2>$null | ConvertFrom-Json
        
        if (-not $probeJson) {
            Write-Host "  [ERROR] Cannot probe video - severely corrupted" -ForegroundColor Red
            $errorCount++
            continue
        }
        
        $videoStream = $probeJson.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
        
        if (-not $videoStream) {
            Write-Host "  [ERROR] No video stream - file is corrupted beyond repair" -ForegroundColor Red
            $errorCount++
            continue
        }
        
        # Detect issues
        $needsReEncode = $false
        $needsRemux = $false
        $issues = @()
        
        # Check FPS corruption
        if ($videoStream.r_frame_rate -match '(\d+)/(\d+)') {
            $fpsNum = [int]$matches[1]
            $fpsDen = [int]$matches[2]
            
            if ($fpsDen -eq 0 -or $fpsNum -gt 1000) {
                $issues += "Corrupted FPS metadata"
                $needsReEncode = $true
            }
        }
        
        # Check duration
        $fileDuration = if ($probeJson.format.duration) { [double]$probeJson.format.duration } else { 0 }
        $streamDuration = if ($videoStream.duration) { [double]$videoStream.duration } else { 0 }
        
        if ($fileDuration -eq 0 -or $streamDuration -eq 0) {
            $issues += "Missing duration"
            $needsRemux = $true
        }
        elseif ([math]::Abs($fileDuration - $streamDuration) -gt 1.0) {
            $issues += "Duration mismatch"
            $needsRemux = $true
        }
        
        # Check if merged file (likely has issues)
        if ($file.Name -match 'merged|merge|combined') {
            $issues += "Merged file (potential glitches)"
            $needsReEncode = $true
        }
        
        if ($issues.Count -eq 0) {
            Write-Host "  [OK] No issues detected - file appears healthy" -ForegroundColor Green
            $skippedCount++
            continue
        }
        
        Write-Host "  [DETECTED] $($issues -join ', ')" -ForegroundColor Yellow
        
        # Build output filename
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $outputFile = Join-Path $file.DirectoryName "${baseName}_FIXED.mp4"
        $tempFile = Join-Path $file.DirectoryName "${baseName}_TEMP.mp4"
        
        # Choose repair strategy
        if ($needsReEncode) {
            Write-Host "  [REPAIR] Re-encoding (fixes metadata + standardizes)..." -ForegroundColor Yellow
            
            #Re-encode to H.264 30fps 1080p (standardize)
            $width = [int]$videoStream.width
            $height = [int]$videoStream.height
            $isPortrait = $height -gt $width
            
            $scale = ""
            if ($isPortrait -and $height -gt 1080) {
                $newHeight = 1080
                $newWidth = [math]::Floor($width * (1080 / $height))
                $newWidth = $newWidth - ($newWidth % 2)
                $scale = "${newWidth}:${newHeight}"
            }
            elseif (-not $isPortrait -and $height -gt 1080) {
                $newHeight = 1080
                $newWidth = [math]::Floor($width * (1080 / $height))
                $newWidth = $newWidth - ($newWidth % 2)
                $scale = "${newWidth}:${newHeight}"
            }
            
            $ffmpegArgs = @(
                "-i", $file.FullName
                "-y"
                "-c:v", "libx264"
                "-preset", "medium"
                "-crf", "23"
                "-r", "30"
            )
            
            if ($scale) {
                $ffmpegArgs += "-vf", "scale=$scale"
            }
            
            $ffmpegArgs += "-c:a", "aac"
            $ffmpegArgs += "-b:a", "128k"
            $ffmpegArgs += "-pix_fmt", "yuv420p"
            $ffmpegArgs += "-movflags", "+faststart"
            $ffmpegArgs += $tempFile
            
            & ffmpeg -hide_banner @ffmpegArgs 2>&1 | Out-Null
            
        }
        else {
            Write-Host "  [REPAIR] Re-muxing (fixes container issues)..." -ForegroundColor Yellow
            
            # Simple remux (no re-encode)
            & ffmpeg -hide_banner -i $file.FullName -y -c copy -movflags +faststart $tempFile 2>&1 | Out-Null
        }
        
        # Verify output
        if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
            $tempSize = (Get-Item $tempFile).Length
            
            if ($tempSize -gt 100KB) {
                Move-Item $tempFile $outputFile -Force
                
                # Preserve timestamps
                $output = Get-Item $outputFile
                $output.CreationTime = $file.CreationTime
                $output.LastWriteTime = $file.LastWriteTime
                
                Write-Host "  [SUCCESS] Repaired: ${baseName}_FIXED.mp4" -ForegroundColor Green
                $repairedCount++
            }
            else {
                Write-Host "  [ERROR] Repair failed - output too small" -ForegroundColor Red
                Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                $errorCount++
            }
        }
        else {
            Write-Host "  [ERROR] Repair failed" -ForegroundColor Red
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $errorCount++
        }
        
    }
    catch {
        Write-Host "  [ERROR] Exception: $_" -ForegroundColor Red
        $errorCount++
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Repaired: $repairedCount" -ForegroundColor Green
Write-Host "  Skipped (healthy): $skippedCount" -ForegroundColor Yellow
Write-Host "  Errors: $errorCount" -ForegroundColor Red
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
