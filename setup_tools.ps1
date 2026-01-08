# ============================================================================
# SETUP TOOLS - Dependency Downloader
# ============================================================================
# This script downloads ffmpeg, ffprobe, and exiftool into the _bin folder.
# ============================================================================

$binDir = Join-Path $PSScriptRoot "_bin"
if (-not (Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir | Out-Null
}

function Download-And-Extract {
    param(
        [string]$Url,
        [string]$ZipFile,
        [string]$ExtractSubPath, # Path inside zip to find the exe
        [string[]]$FilesToKeep
    )

    Write-Host "[INFO] Downloading $Url..." -ForegroundColor Cyan
    $zipPath = Join-Path $binDir $ZipFile
    Invoke-WebRequest -Uri $Url -OutFile $zipPath

    Write-Host "[INFO] Extracting $ZipFile..." -ForegroundColor Cyan
    $tempExtract = Join-Path $binDir "temp_extract"
    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $tempExtract

    foreach ($file in $FilesToKeep) {
        $foundFile = Get-ChildItem -Path $tempExtract -Filter $file -Recurse | Select-Object -First 1
        if ($foundFile) {
            $dest = Join-Path $binDir $foundFile.Name
            Move-Item $foundFile.FullName $dest -Force
            Write-Host "  [OK] Saved: $($foundFile.Name)" -ForegroundColor Green
        }
    }

    Remove-Item $zipPath -Force
    Remove-Item $tempExtract -Recurse -Force
}

# 1. Download EXIFTOOL
Write-Host "--- EXIFTOOL ---" -ForegroundColor Yellow
$exiftoolUrl = "https://exiftool.org/exiftool-13.10.zip"
Download-And-Extract -Url $exiftoolUrl -ZipFile "exiftool.zip" -FilesToKeep @("exiftool(-k).exe")
if (Test-Path (Join-Path $binDir "exiftool(-k).exe")) {
    Rename-Item (Join-Path $binDir "exiftool(-k).exe") (Join-Path $binDir "exiftool.exe") -Force
}

# 2. Download FFmpeg
Write-Host "`n--- FFmpeg ---" -ForegroundColor Yellow
# Using a stable direct link to essentials build
$ffmpegUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
Download-And-Extract -Url $ffmpegUrl -ZipFile "ffmpeg.zip" -FilesToKeep @("ffmpeg.exe", "ffprobe.exe")

Write-Host "`n[SUCCESS] Setup complete! Tools are in: $binDir" -ForegroundColor Green
Write-Host "Updating local scripts to use these tools...`n"

# Verify
$tools = @("ffmpeg.exe", "ffprobe.exe", "exiftool.exe")
foreach ($tool in $tools) {
    if (Test-Path (Join-Path $binDir $tool)) {
        Write-Host "  [INSTALLED] $tool" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $tool" -ForegroundColor Red
    }
}
