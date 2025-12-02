<# 
.SYNOPSIS
  Converts 4K videos -> 1080p (HEVC) and separates High FPS videos (>=60) into a dedicated folder.
  Preserves the same filename (with or without suffix) and folder structure.

.PARAMETER Root
  Source root directory to scan recursively.

.PARAMETER OutputBase
  Destination root directory. Subfolders "4K" and/or "HighFPS" will be created inside.

.PARAMETER NoSuffix
  If present, does not add any suffix to the output filename.

.PARAMETER StageHighFps
  If present, files with FPS >= threshold are converted (without resizing) and saved in OutputBase\HighFPS\...

.PARAMETER HighFpsDir
  Alternative path to save High FPS videos (if you want to keep them outside OutputBase).
  If not specified, uses OutputBase\HighFPS.

.PARAMETER FpsThreshold
  Threshold to consider "High FPS". Default: 60.

.PARAMETER DryRun
  Prints what would happen without executing ffmpeg.

.NOTE
  Requires: ffprobe/ffmpeg in PATH.
#>

param(
  [Parameter(Mandatory=$true)] [string]$Root,
  [Parameter(Mandatory=$true)] [string]$OutputBase,
  [switch]$NoSuffix,
  [switch]$StageHighFps,
  [string]$HighFpsDir,
  [int]$FpsThreshold = 60,
  [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------
function Write-Info($msg){ Write-Host $msg -ForegroundColor Cyan }
function Write-Warn($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Err ($msg){ Write-Host $msg -ForegroundColor Red }

function Check-Command($cmd) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Err "[ERROR] $cmd not found in PATH. Please install it."
        exit 1
    }
}

function Get-RelativePath([string]$base, [string]$path) {
  return [System.IO.Path]::GetRelativePath((Resolve-Path $base), (Resolve-Path $path))
}

function Probe-Video($path) {
  $args = @(
    "-v","error",
    "-print_format","json",
    "-show_entries","format:stream=index,codec_type,width,height,avg_frame_rate",
    "--",$path
  )
  $p = Start-Process -FilePath "ffprobe" -ArgumentList $args -NoNewWindow -PassThru -Wait -RedirectStandardOutput "STDOUT.json" -RedirectStandardError "STDERR.txt"
  try {
    $json = Get-Content -Raw "STDOUT.json" | ConvertFrom-Json
  } catch {
    $json = $null
  } finally {
    Remove-Item -Force -ErrorAction SilentlyContinue "STDOUT.json","STDERR.txt"
  }
  return $json
}

function Parse-Fps($r) {
  if (-not $r) { return $null }
  if ($r -is [string] -and $r -match "^\d+(\.\d+)?$") { return [double]$r }
  if ($r -is [string] -and $r -match "^\d+/\d+$") {
    $num,$den = $r -split "/"
    if ([double]$den -eq 0) { return $null }
    return ([double]$num / [double]$den)
  }
  return $null
}

# ------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------
Check-Command "ffmpeg"
Check-Command "ffprobe"

# ------------------------------------------------------------
# Folder Preparation
# ------------------------------------------------------------
if (-not (Test-Path $Root)) {
    Write-Err "Source root does not exist: $Root"
    exit 1
}

$Root = (Resolve-Path $Root).Path
$OutputBase = (Resolve-Path $OutputBase).Path # OutputBase might not exist yet, but we assume parent does or we create it?
# Resolve-Path errors if path doesn't exist. Let's create OutputBase if needed.
if (-not (Test-Path $OutputBase)) {
    New-Item -ItemType Directory -Force -Path $OutputBase | Out-Null
    $OutputBase = (Resolve-Path $OutputBase).Path
}

if (-not $HighFpsDir) { $HighFpsDir = Join-Path $OutputBase "HighFPS" }

# Stats
$cand4K = 0
$candHigh = 0
$converted = 0
$skippedSmallHF = 0
$skippedOther = 0
$metaErrors = 0
$errors = 0

# Extension filters
$exts = @(".mp4",".mov",".m4v")

# Scan
Write-Info "Scanning: $Root"
$files = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $exts -contains $_.Extension.ToLowerInvariant() }

# First pass: candidate list
$planned = New-Object System.Collections.Generic.List[object]

foreach ($f in $files) {
  $probe = $null
  try {
    $probe = Probe-Video $f.FullName
  } catch {
    $probe = $null
  }

  if (-not $probe -or -not $probe.streams) {
    Write-Warn "[ffprobe] Unable to read metadata (missing moov atom or corrupt file): $($f.FullName)"
    $metaErrors++
    continue
  }

  $v = $probe.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
  if (-not $v) { 
    Write-Warn "[ffprobe] No video stream: $($f.FullName)"
    $metaErrors++
    continue 
  }

  $w = [int]$v.width
  $h = [int]$v.height
  $fps = Parse-Fps $v.avg_frame_rate

  $hasAudio = ($probe.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1) -ne $null
  $relDir = Get-RelativePath $Root $f.DirectoryName

  $is4K = ($w -ge 3840 -or $h -ge 2160)
  $isHigh = ($StageHighFps -and $fps -ne $null -and $fps -ge $FpsThreshold)

  if ($is4K) {
    $cand4K++
    $destRoot = Join-Path $OutputBase "4K"
    $destDir = Join-Path $destRoot $relDir
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $ext      = [System.IO.Path]::GetExtension($f.Name)
    $outName  = if ($NoSuffix) { "$baseName$ext" } else { "${baseName}_1080p$ext" }
    $outPath  = Join-Path $destDir $outName

    $planned.Add([pscustomobject]@{
      Src = $f.FullName; Cat="4K"; W=$w; H=$h; FPS=$fps; HasAudio=$hasAudio; Out=$outPath
    })
  }
  elseif ($isHigh) {
    # optional: ignore "small" files to save time
    if ($w -lt 1280 -or $h -lt 720) {
      $skippedSmallHF++
      continue
    }
    $candHigh++
    $destRoot = $HighFpsDir
    $destDir = Join-Path $destRoot $relDir
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $ext      = [System.IO.Path]::GetExtension($f.Name)
    $outName  = if ($NoSuffix) { "$baseName$ext" } else { "${baseName}_HF$ext" }
    $outPath  = Join-Path $destDir $outName

    $planned.Add([pscustomobject]@{
      Src = $f.FullName; Cat="HighFPS"; W=$w; H=$h; FPS=$fps; HasAudio=$hasAudio; Out=$outPath
    })
  }
  else {
    $skippedOther++
  }
}

# Initial DRY RUN Report
foreach ($p in $planned) {
  $cat = $p.Cat
  $dst = $p.Out
  if ($DryRun) {
    Write-Host "[DRY RUN] $($p.Src) -> $dst  [$cat]" -ForegroundColor DarkGray
  }
}

Write-Info "------ SUMMARY ------"
Write-Host ("Candidates: {0} (4K: {1}, HighFPS: {2})" -f ($planned.Count), $cand4K, $candHigh)
Write-Host ("Skipped HighFPS but small (<1280x720): {0}" -f $skippedSmallHF)
Write-Host ("Others skipped/not eligible: {0}" -f $skippedOther)
Write-Host ("Metadata read errors: {0}" -f $metaErrors)

if ($DryRun) { 
  Write-Info "DRY RUN active: no conversion executed."
  exit 0 
}

# ------------------------------------------------------------
# Conversion
# ------------------------------------------------------------
$index = 0
$total = $planned.Count

foreach ($p in $planned) {
  $index++
  $cat = $p.Cat
  $src = $p.Src
  $out = $p.Out
  $hasAudio = [bool]$p.HasAudio

  # Create directory
  New-Item -ItemType Directory -Force -Path ([System.IO.Path]::GetDirectoryName($out)) | Out-Null

  # Video filters:
  if ($cat -eq "4K") {
    # Resize height to 1080, keep aspect ratio; force even dimensions; YUV420p for compatibility;
    $vf = 'scale=-2:1080:flags=lanczos,scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p'
  } else {
    # HighFPS: no resize; only force even dimensions + YUV420p
    $vf = 'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p'
  }

  $mapArgs = @("-map","0:v:0")
  if ($hasAudio) { $mapArgs += @("-map","0:a:0") }

  $audioArgs = @()
  if ($hasAudio) { $audioArgs = @("-c:a","aac","-b:a","160k") }

  $args = @(
    "-y",
    "-hide_banner",
    "-v","warning",
    "-stats",
    "-i",$src
  ) + $mapArgs + @(
    "-c:v","libx265","-preset","medium","-crf","24",
    "-vf",$vf,
    "-tag:v","hvc1",            # QuickTime/iOS compatibility
    "-movflags","+faststart"    # moov at beginning
  ) + $audioArgs + @(
    "--",$out
  )

  Write-Info ("Converting video {0}/{1} - {2} ({3}x{4}, {5} fps) - {6}" -f $index,$total, (Split-Path $src -Leaf), $p.W,$p.H,("{0:N3}" -f $p.FPS), $cat)
  Write-Host ("Converting: {0} -> {1}  [{2}]" -f $src, $out, $cat)

  try {
    $proc = Start-Process -FilePath "ffmpeg" -ArgumentList $args -NoNewWindow -PassThru -Wait
    if ($proc.ExitCode -ne 0) {
      Write-Warn ("WARNING: Error on: {0}" -f $src)
      $errors++
      continue
    }
    $converted++
  }
  catch {
    Write-Warn ("WARNING: Exception on: {0}  -> {1}" -f $src, $_.Exception.Message)
    $errors++
  }
}

Write-Host ""
Write-Info "------ FINISHED ------"
Write-Host ("Converted: {0}/{1}" -f $converted,$total)
Write-Host ("Conversion errors: {0}" -f $errors)
Write-Host ("Done.")
