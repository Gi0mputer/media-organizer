param(
    [string]$SourcePath,
    [switch]$Overwrite = $false,
    [int]$TargetHeight = 1080,
    [int]$TargetFPS = 30,
    [string]$TargetCodec = "hevc_nvenc", # Use "libx265" if no NVIDIA GPU
    [int]$CRF = 23 # Quality (lower = better, 23 is standard)
)

# Check dependencies
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "FFmpeg not found! Please install it."
    exit
}

if ([string]::IsNullOrWhiteSpace($SourcePath) -or -not (Test-Path $SourcePath)) {
    Write-Host "Please provide a valid SourcePath." -ForegroundColor Red
    exit
}

$OutputDir = Join-Path $SourcePath "Normalized"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

Write-Host "=== VIDEO STANDARDIZER ===" -ForegroundColor Cyan
Write-Host "Source: $SourcePath"
Write-Host "Target: $TargetHeight p @ $TargetFPS fps ($TargetCodec)"
Write-Host "Output: $OutputDir"
Write-Host ""

$files = Get-ChildItem -Path $SourcePath -File | Where-Object { @('.mp4', '.mov', '.avi', '.mkv', '.m4v') -contains $_.Extension.ToLower() }
$total = $files.Count
$current = 0

foreach ($file in $files) {
    $current++
    $pct = [math]::Round(($current / $total) * 100, 1)
    $outFile = Join-Path $OutputDir ($file.BaseName + ".mp4")
    
    Write-Host "[$current/$total - $pct%] Processing: $($file.Name)" -NoNewline
    
    if (Test-Path $outFile -And -not $Overwrite) {
        Write-Host " [SKIP - Exists]" -ForegroundColor Yellow
        continue
    }

    # Get file info
    $probe = ffprobe -v error -select_streams v:0 -show_entries stream=width, height, r_frame_rate, codec_name -of csv=p=0 "$($file.FullName)" 2>$null
    if (-not $probe) {
        Write-Host " [ERROR - Probe Failed]" -ForegroundColor Red
        continue
    }
    
    $width, $height, $fpsStr, $codec = $probe -split ','
    
    # Calculate FPS
    try {
        $num, $den = $fpsStr -split '/'
        $fps = [double]$num / [double]$den
    }
    catch {
        $fps = 30
    }

    # Decide if conversion is needed
    $needsConvert = $false
    $reason = @()

    if ($height -gt $TargetHeight) { $needsConvert = $true; $reason += "Res > $TargetHeight" }
    if ($fps -gt ($TargetFPS + 1)) { $needsConvert = $true; $reason += "FPS > $TargetFPS" }
    if ($codec -ne "hevc") { $needsConvert = $true; $reason += "Codec != HEVC" }
    if ($file.Extension.ToLower() -ne ".mp4") { $needsConvert = $true; $reason += "Container != MP4" }

    if (-not $needsConvert) {
        Write-Host " [COPY - Already Standard]" -ForegroundColor Green
        Copy-Item $file.FullName $outFile -Force
        continue
    }

    Write-Host " [CONVERTING: $($reason -join ', ')]" -ForegroundColor Cyan

    # Get Creation Time
    $ctime = $file.CreationTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")
    
    # FFmpeg Command
    # -vf: Scale if needed (maintaining aspect ratio), FPS filter
    # -c:v: HEVC
    # -c:a: AAC (standard)
    # -map_metadata 0: Copy global metadata
    
    $scaleFilter = "scale=-2:min(ih\,$TargetHeight)"
    $fpsFilter = "fps=$TargetFPS"
    
    $cmdArgs = @(
        "-y",
        "-hwaccel", "cuda",
        "-i", "`"$($file.FullName)`"",
        "-c:v", $TargetCodec,
        "-preset", "p4", # Medium preset
        "-cq", $CRF,
        "-vf", "`"$scaleFilter,$fpsFilter`"",
        "-c:a", "aac",
        "-b:a", "128k",
        "-map_metadata", "0",
        "-metadata", "creation_time=`"$ctime`"",
        "-movflags", "+faststart",
        "`"$outFile`""
    )
    
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList $cmdArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -eq 0) {
        # Sync file timestamps
        $newItem = Get-Item $outFile
        $newItem.CreationTime = $file.CreationTime
        $newItem.LastWriteTime = $file.LastWriteTime
        Write-Host "   -> Done. Saved to Normalized folder." -ForegroundColor Green
    }
    else {
        Write-Host "   -> FAILED (Exit Code: $($process.ExitCode))" -ForegroundColor Red
        if (Test-Path $outFile) { Remove-Item $outFile }
    }
}

Write-Host "`nAll tasks completed." -ForegroundColor Green
