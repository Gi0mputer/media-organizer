# ============================================================================
# VIDEO HEALTH DIAGNOSTICS - Intelligent Analyzer
# ============================================================================
# Purpose: Detect corrupted metadata, merge issues, playback problems
# Output: Categorized report with repair suggestions
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ScanPath = "D:\",
    
    [Parameter(Mandatory = $false)]
    [int]$MaxSamples = 500,

    [Parameter(Mandatory = $false)]
    [switch]$NoPause
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  VIDEO HEALTH DIAGNOSTICS" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$issues = @{
    CorruptedMetadata = @()
    MergeProblems     = @()
    PlaybackIssues    = @()
    FormatIssues      = @()
    HealthyButSuspect = @()
}

Write-Host "[SCANNING] $ScanPath for video files..." -ForegroundColor Yellow
$videos = Get-ChildItem $ScanPath -Recurse -File -ErrorAction SilentlyContinue | 
Where-Object { $_.Extension -match '\.(mp4|mov|avi|mkv|m4v)$' } | 
Select-Object -First $MaxSamples

Write-Host "[FOUND] $($videos.Count) videos to analyze`n" -ForegroundColor Green

$processed = 0

foreach ($video in $videos) {
    $processed++
    $percent = [math]::Round(($processed / $videos.Count) * 100, 1)
    Write-Progress -Activity "Analyzing videos" -Status "$processed/$($videos.Count) - $($video.Name)" -PercentComplete $percent
    
    $problemsFound = @()
    $severity = "OK"
    
    try {
        # Probe video
        $probeJson = & ffprobe -v quiet -print_format json -show_format -show_streams -show_error $video.FullName 2>$null | ConvertFrom-Json
        
        if (-not $probeJson) {
            $issues.PlaybackIssues += [PSCustomObject]@{
                File       = $video.FullName
                Problem    = "Cannot probe - severely corrupted"
                Severity   = "CRITICAL"
                Suggestion = "Re-encode or discard"
            }
            continue
        }
        
        $format = $probeJson.format
        $videoStream = $probeJson.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
        $audioStream = $probeJson.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
        
        if (-not $videoStream) {
            $issues.PlaybackIssues += [PSCustomObject]@{
                File       = $video.FullName
                Problem    = "No video stream found"
                Severity   = "CRITICAL"
                Suggestion = "Corrupted file - discard"
            }
            continue
        }
        
        # CHECK 1: FPS Issues
        if ($videoStream.r_frame_rate -match '(\d+)/(\d+)') {
            $fpsNum = [int]$matches[1]
            $fpsDen = [int]$matches[2]
            
            if ($fpsDen -eq 0) {
                $problemsFound += "FPS division by zero"
                $severity = "HIGH"
            }
            elseif ($fpsNum -gt 100000) {
                # Truly corrupted (e.g., 90000fps metadata errors)
                # Standard NTSC is 30000/1001 = 29.97, which is OK
                $fps = [math]::Round($fpsNum / $fpsDen, 2)
                $problemsFound += "FPS metadata corrupted: $fps fps"
                $severity = "HIGH"
            }
            elseif ($fpsNum -lt $fpsDen -and $fpsDen -gt 100) {
                $problemsFound += "FPS suspiciously low: $fpsNum/$fpsDen"
                $severity = "MEDIUM"
            }
        }
        
        # CHECK 2: Duration Issues
        $fileDuration = $null
        $streamDuration = $null
        
        if ($format.duration) { $fileDuration = [double]$format.duration }
        if ($videoStream.duration) { $streamDuration = [double]$videoStream.duration }
        
        if ($fileDuration -and $streamDuration) {
            $diff = [math]::Abs($fileDuration - $streamDuration)
            if ($diff -gt 1.0) {
                $problemsFound += "Duration mismatch: file=$fileDuration stream=$streamDuration"
                $severity = "MEDIUM"
            }
        }
        
        if ($fileDuration -eq 0 -or $streamDuration -eq 0) {
            $problemsFound += "Duration is zero - corrupted metadata"
            $severity = "HIGH"
        }
        
        # CHECK 3: Codec Compatibility (LosslessCut merge issues)
        $codec = $videoStream.codec_name
        $profile = $videoStream.profile
        
        if ($codec -notin @('h264', 'hevc', 'vp9')) {
            $problemsFound += "Non-standard codec: $codec (merge problems likely)"
            $severity = if ($severity -eq "OK") { "LOW" } else { $severity }
        }
        
        # CHECK 4: Bitrate Anomalies
        if ($format.bit_rate) {
            $bitrate = [int]$format.bit_rate
            $width = [int]$videoStream.width
            $height = [int]$videoStream.height
            $pixels = $width * $height
            
            # Suspiciously low bitrate for resolution
            if ($pixels -gt 2000000 -and $bitrate -lt 1000000) {
                # 1080p+ with <1Mbps
                $problemsFound += "Bitrate very low for resolution (${bitrate}bps for ${width}x${height})"
                $severity = if ($severity -eq "OK") { "LOW" } else { $severity }
            }
            
            # Suspiciously high bitrate
            if ($bitrate -gt 50000000) {
                # >50Mbps
                $problemsFound += "Extremely high bitrate: $(([math]::Round($bitrate/1000000,1)))Mbps"
                $severity = if ($severity -eq "OK") { "LOW" } else { $severity }
            }
        }
        
        # CHECK 5: Merged File Detection (heuristics)
        $isMerged = $false
        if ($video.Name -match 'merged|merge|_M\d+|combined') {
            $isMerged = $true
        }
        
        # Check for multiple edit lists (sign of merge)
        if ($probeJson.format.tags) {
            $tags = $probeJson.format.tags | ConvertTo-Json
            if ($tags -match 'edit|merge') {
                $isMerged = $true
            }
        }
        
        if ($isMerged -and $problemsFound.Count -gt 0) {
            $problemsFound += "MERGED file with issues - likely LosslessCut bad merge"
        }
        
        # CHECK 6: Container Issues
        $container = $format.format_name
        if ($container -notmatch 'mp4|mov|avi|matroska') {
            $problemsFound += "Unusual container: $container"
            $severity = if ($severity -eq "OK") { "LOW" } else { $severity }
        }
        
        # CHECK 7: Missing moov atom (MP4/MOV specific)
        if ($video.Extension -match '\.(mp4|mov)$') {
            # This requires deeper inspection, skip for now
            # Can add with: ffmpeg -i file.mp4 -c copy -f null -
        }
        
        # Categorize
        if ($problemsFound.Count -gt 0) {
            $issue = [PSCustomObject]@{
                File       = $video.FullName
                FileName   = $video.Name
                Problems   = $problemsFound -join "; "
                Severity   = $severity
                IsMerged   = $isMerged
                Codec      = $codec
                Resolution = "$($videoStream.width)x$($videoStream.height)"
                Suggestion = ""
            }
            
            # Add suggestion
            if ($severity -eq "HIGH" -or $severity -eq "CRITICAL") {
                $issue.Suggestion = "Re-encode with STANDARDIZE_VIDEO.bat"
            }
            elseif ($isMerged) {
                $issue.Suggestion = "Re-merge with standardized input files or re-encode"
            }
            else {
                $issue.Suggestion = "Monitor - may need metadata fix or re-encode"
            }
            
            # Categorize by type
            if ($problemsFound -match 'FPS|Duration') {
                $issues.CorruptedMetadata += $issue
            }
            if ($isMerged) {
                $issues.MergeProblems += $issue
            }
            if ($severity -in @('HIGH', 'CRITICAL')) {
                $issues.PlaybackIssues += $issue
            }
            if ($problemsFound -match 'codec|bitrate|container') {
                $issues.FormatIssues += $issue
            }
            if ($severity -eq 'LOW' -or $severity -eq 'MEDIUM') {
                $issues.HealthyButSuspect += $issue
            }
        }
        
    }
    catch {
        $issues.PlaybackIssues += [PSCustomObject]@{
            File       = $video.FullName
            Problem    = "Exception during analysis: $_"
            Severity   = "CRITICAL"
            Suggestion = "Verify file integrity"
        }
    }
}

Write-Progress -Activity "Analyzing videos" -Completed

# Generate Report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC REPORT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$reportPath = "c:\Users\ASUS\Desktop\Batchs\1_LLM_Automation\Analysis\VIDEO_HEALTH_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$report = @"
# Video Health Diagnostic Report
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Scanned: $ScanPath
Files Analyzed: $($videos.Count)

## Summary

| Category | Count |
|----------|-------|
| Corrupted Metadata | $($issues.CorruptedMetadata.Count) |
| Merge Problems | $($issues.MergeProblems.Count) |
| Playback Issues | $($issues.PlaybackIssues.Count) |
| Format Issues | $($issues.FormatIssues.Count) |
| Suspect but Healthy | $($issues.HealthyButSuspect.Count) |

---
"@

$report += "`n## [CRITICAL] Playback Issues ($($issues.PlaybackIssues.Count))`n"

if ($issues.PlaybackIssues.Count -gt 0) {
    foreach ($issue in $issues.PlaybackIssues | Select-Object -First 20) {
        $report += "`n### $($issue.FileName)`n"
        $report += "- **Problems**: $($issue.Problems)`n"
        $report += "- **Severity**: $($issue.Severity)`n"
        $report += "- **Suggestion**: $($issue.Suggestion)`n"
        $report += "- **Path**: ``$($issue.File)```n"
    }
    if ($issues.PlaybackIssues.Count -gt 20) {
        $report += "`n*... and $($issues.PlaybackIssues.Count - 20) more*`n"
    }
}
else {
    $report += "`nNo critical playback issues found!`n"
}

$report += "`n---`n`n## [WARNING] Merge Problems ($($issues.MergeProblems.Count))`n"

if ($issues.MergeProblems.Count -gt 0) {
    foreach ($issue in $issues.MergeProblems | Select-Object -First 15) {
        $report += "`n### $($issue.FileName)`n"
        $report += "- **Problems**: $($issue.Problems)`n"
        $report += "- **Codec**: $($issue.Codec) @ $($issue.Resolution)`n"
        $report += "- **Suggestion**: $($issue.Suggestion)`n"
        $report += "- **Path**: ``$($issue.File)```n"
    }
    if ($issues.MergeProblems.Count -gt 15) {
        $report += "`n*... and $($issues.MergeProblems.Count - 15) more*`n"
    }
}
else {
    $report += "`nNo merge problems detected!`n"
}

$report += "`n---`n`n## [INFO] Corrupted Metadata ($($issues.CorruptedMetadata.Count))`n"

if ($issues.CorruptedMetadata.Count -gt 0) {
    foreach ($issue in $issues.CorruptedMetadata | Select-Object -First 15) {
        $report += "- **$($issue.FileName)**: $($issue.Problems) - $($issue.Suggestion)`n"
    }
}
else {
    $report += "`nNo metadata corruption found!`n"
}

$report += "`n---`n`n## Recommendations`n`n"

if ($issues.PlaybackIssues.Count -gt 0) {
    $report += "### Immediate Action Required ($($issues.PlaybackIssues.Count) files)`n"
    $report += "1. Re-encode critical files with ``STANDARDIZE_VIDEO.bat```n"
    $report += "2. Verify output plays correctly`n"
    $report += "3. Replace original with standardized version`n`n"
}

if ($issues.MergeProblems.Count -gt 0) {
    $report += "### Merge Issues ($($issues.MergeProblems.Count) files)`n"
    $report += "1. Re-encode source files BEFORE merging`n"
    $report += "2. Use ``STANDARDIZE_VIDEO.bat`` on all clips`n"
    $report += "3. Re-merge with LosslessCut`n`n"
}

$report += "### Batch Repair Workflow`n"
$report += "1. Drag problematic files/folders onto ``REPAIR_VIDEO.bat```n"
$report += "2. Script will auto-fix metadata and re-encode if needed`n"
$report += "3. Verify output in VLC/Media Player`n"

$report | Out-File $reportPath -Encoding UTF8

Write-Host "Report saved: $reportPath`n" -ForegroundColor Green

# Console Summary
Write-Host "[CRITICAL] Issues: $($issues.PlaybackIssues.Count)" -ForegroundColor Red
Write-Host "[WARNING] Merge Problems: $($issues.MergeProblems.Count)" -ForegroundColor Yellow
Write-Host "[INFO] Metadata Issues: $($issues.CorruptedMetadata.Count)" -ForegroundColor Yellow
Write-Host "[OK] Suspect but OK: $($issues.HealthyButSuspect.Count)" -ForegroundColor Green

if (-not $NoPause) {
    Write-Host "`nPress any key to exit..."
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch {}
}
