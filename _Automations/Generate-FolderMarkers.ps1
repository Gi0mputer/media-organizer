param(
    [string[]]$RootPaths = @("D:\", "E:\"),
    [int]$HeavyThresholdMB = 500
)

$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== GENERATING FOLDER INFO MARKERS ===" -ForegroundColor Cyan
Write-Host "Heavy File Threshold: $HeavyThresholdMB MB"

foreach ($root in $RootPaths) {
    if (-not (Test-Path $root)) { continue }
    
    # Get Year Folders
    $YearFolders = Get-ChildItem $root -Directory | Where-Object { $_.Name -match "^(20\d{2}|19\d{2})" }

    foreach ($yf in $YearFolders) {
        $eventFolders = Get-ChildItem $yf.FullName -Directory
        
        foreach ($ev in $eventFolders) {
            # Skip special folders
            if ($ev.Name.StartsWith("_")) { continue }
            
            # Analyze Files
            $files = Get-ChildItem $ev.FullName -File -Recurse
            if ($files.Count -eq 0) { continue }
            
            $totalSize = ($files | Measure-Object -Property Length -Sum).Sum
            $totalSizeMB = [math]::Round($totalSize / 1MB, 0)
            $totalSizeGB = [math]::Round($totalSize / 1GB, 2)
            
            # Date Range
            $dates = $files | Select-Object LastWriteTime | Sort-Object LastWriteTime
            $minDate = $dates[0].LastWriteTime.ToString("yyyy-MM-dd")
            $maxDate = $dates[-1].LastWriteTime.ToString("yyyy-MM-dd")
            
            # Heavy Analysis
            $heavyFiles = $files | Where-Object { $_.Length -gt ($HeavyThresholdMB * 1MB) } | Sort-Object Length -Descending
            $heavyCount = $heavyFiles.Count
            $heavySize = ($heavyFiles | Measure-Object -Property Length -Sum).Sum
            $heavySizeGB = [math]::Round($heavySize / 1GB, 2)
            
            # Construct File Name
            # !_INFO_[Count]_[Size]_[Date].txt
            # e.g. !_INFO_120f_4GB.txt
            
            $sizeLabel = if ($totalSizeGB -ge 1) { "$($totalSizeGB)GB" } else { "$($totalSizeMB)MB" }
            $markerName = "!_INFO_$($files.Count)f_$($sizeLabel).txt"
            $markerPath = Join-Path $ev.FullName $markerName
            
            # Delete old markers if exist
            Get-ChildItem $ev.FullName -Filter "!_INFO_*.txt" | Remove-Item -Force
            
            # Create Content
            $sb = [System.Text.StringBuilder]::new()
            [void]$sb.AppendLine("=== FOLDER ANALYSIS: $($ev.Name) ===")
            [void]$sb.AppendLine("Total Files: $($files.Count)")
            [void]$sb.AppendLine("Total Size : $sizeLabel")
            [void]$sb.AppendLine("Date Range : $minDate to $maxDate")
            [void]$sb.AppendLine("")
            
            if ($heavyCount -gt 0) {
                [void]$sb.AppendLine("⚠️  HEAVY FILES DETECTED (> $HeavyThresholdMB MB) ⚠️")
                [void]$sb.AppendLine("Count: $heavyCount files")
                [void]$sb.AppendLine("Size : $heavySizeGB GB (takes up $([math]::Round(($heavySize/$totalSize)*100,0))% of folder space)")
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("--- Top Heavy Files ---")
                foreach ($f in $heavyFiles) {
                    $fsGB = [math]::Round($f.Length / 1GB, 2)
                    [void]$sb.AppendLine("- $($f.Name)  [$fsGB GB]")
                }
                [void]$sb.AppendLine("")
                [void]$sb.AppendLine("SUGGESTION: Consider moving these $heavyCount files to a '_HEAVY' subfolder.")
            }
            else {
                [void]$sb.AppendLine("✅ No heavy files (> $HeavyThresholdMB MB). Folder is balanced.")
            }
            
            Set-Content -Path $markerPath -Value $sb.ToString()
            Write-Host "Generated: $markerPath"
        }
    }
}
