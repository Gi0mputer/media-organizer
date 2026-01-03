param(
    [string[]]$SearchPaths = @("D:\", "E:\"),
    [int]$SizeThresholdMB = 200,   # Files smaller than this unlikely to be 4K raw drone footage
    [string]$ReportFile = "$env:USERPROFILE\Desktop\DroneFootageReport.csv"
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== FINDING HEAVY DRONE FOOTAGE ===" -ForegroundColor Cyan
Write-Host "Scanning for video files > $SizeThresholdMB MB..."

$results = @()

foreach ($path in $SearchPaths) {
    if (-not (Test-Path $path)) { continue }
    
    # Fast scan for large video files
    $files = Get-ChildItem -Path $path -Recurse -File -Include "*.mp4", "*.mov" | Where-Object { $_.Length -gt ($SizeThresholdMB * 1MB) }
    
    foreach ($file in $files) {
        # Check if it looks like drone footage (DJI, generic numbers)
        # Assuming most drone footage matches DJI* or just Cxxxx.MP4
        # But let's verify with ffprobe if possible, or just log size/name
        
        # Simple heuristic first:
        $isDroneLike = ($file.Name -match "DJI" -or $file.Name -match "C\d{4}\.MP4" -or $file.Name -match "GX\d{4}")
        
        if ($isDroneLike -or $file.Length -gt 500MB) {
            # Try to get bitrate/res with ffprobe
            $width = 0
            $height = 0
            $bitrate = 0
            $duration = 0
            
            # Run ffprobe (fast mode)
            $probe = ffprobe -v error -select_streams v:0 -show_entries stream=width, height, bit_rate -show_entries format=duration -of default=noprint_wrappers=1 "$($file.FullName)" 2>$null
            
            if ($probe) {
                foreach ($line in $probe) {
                    if ($line -match "width=(\d+)") { $width = [int]$matches[1] }
                    if ($line -match "height=(\d+)") { $height = [int]$matches[1] }
                    if ($line -match "bit_rate=(\d+)") { $bitrate = [long]$matches[1] } # bps
                    if ($line -match "duration=([\d\.]+)") { $duration = [double]$matches[1] }
                }
            }
            
            # Filter: High Bitrate (> 60 Mbps) OR High Res (4K)
            if ($bitrate -gt 60000000 -or $width -ge 2600) {
                $results += [PSCustomObject]@{
                    Path        = $file.FullName
                    Name        = $file.Name
                    Folder      = $file.DirectoryName
                    SizeGB      = [math]::Round($file.Length / 1GB, 2)
                    Resolution  = "${width}x${height}"
                    BitrateMbps = [math]::Round($bitrate / 1000000, 1)
                    DurationSec = [math]::Round($duration, 0)
                }
                Write-Host "Found: $($file.Name) [${width}x${height}, $bitrate Mbps]" -ForegroundColor Green
            }
        }
    }
}

# Export
if ($results.Count -gt 0) {
    $results | Sort-Object SizeGB -Descending | Export-Csv -Path $ReportFile -NoTypeInformation
    Write-Host "`nFound $($results.Count) heavy drone files."
    Write-Host "Report saved to: $ReportFile"
    
    # Show Top 10
    $results | Sort-Object SizeGB -Descending | Select-Object -First 10 | Format-Table -AutoSize | Out-String | Write-Host
}
else {
    Write-Host "No heavy drone footage found matching criteria."
}
