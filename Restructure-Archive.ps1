param(
    [string]$RootPath = "E:\",
    [string]$ExifToolPath = "C:\Windows\exiftool.exe",
    [switch]$Execute = $false
)

$ErrorActionPreference = 'SilentlyContinue'
$YearPattern = "^\d{4}( e pre)?$" 

function Get-MediaYear {
    param($FileObject)
    # 1. Filename Pattern (High confidence)
    if ($FileObject.Name -match "20(\d{2})[-_]?(\d{2})[-_]?(\d{2})") {
        return [int]"20$($matches[1])"
    }
    if ($FileObject.Name -match "^(19|20)\d{2}") {
        return [int]$matches[0]
    }
    # 2. LastWriteTime (Fallback)
    return [int]$FileObject.LastWriteTime.Year
}

$ActionsLog = @()
$MergeCandidates = @{} 

Write-Host "=== ARCHIVE RESTRUCTURING ANALYSIS ===" -ForegroundColor Cyan
if ($Execute) { Write-Host "WARNING: EXECUTION MODE ENABLED - Changes will be applied!" -ForegroundColor Red }
else { Write-Host "INFO: PREVIEW MODE - No changes will be made." -ForegroundColor Yellow }

# 1. Scan Folders
$yearFolders = Get-ChildItem -Path $RootPath -Directory | Where-Object { $_.Name -match $YearPattern }

foreach ($yFolder in $yearFolders) {
    # Extract numeric year
    $parentYear = 0
    if ($yFolder.Name -match "^(\d{4})") { $parentYear = [int]$matches[1] }
    
    $subFolders = Get-ChildItem -Path $yFolder.FullName -Directory
    
    foreach ($sub in $subFolders) {
        # Track for merge candidates
        if (-not $MergeCandidates.ContainsKey($sub.Name)) { $MergeCandidates[$sub.Name] = @() }
        $MergeCandidates[$sub.Name] += $sub.FullName

        $files = Get-ChildItem -Path $sub.FullName -File -Recurse | Where-Object { $_.Extension -match "\.(mp4|mov|jpg|png|heic|avi)$" }
        if ($files.Count -eq 0) { continue }

        $stat = @{}
        $minDate = [DateTime]::MaxValue
        $maxDate = [DateTime]::MinValue
        
        foreach ($f in $files) {
            $y = Get-MediaYear $f
            if ($stat.ContainsKey($y)) { $stat[$y]++ } else { $stat[$y] = 1 }
            
            if ($f.LastWriteTime -lt $minDate) { $minDate = $f.LastWriteTime }
            if ($f.LastWriteTime -gt $maxDate) { $maxDate = $f.LastWriteTime }
        }

        # Calculate Dominant Year
        $sortedStats = $stat.GetEnumerator() | Sort-Object Value -Descending
        $dominantYear = [int]$sortedStats[0].Name
        $dominantCount = $sortedStats[0].Value
        $totalFiles = $files.Count
        if ($totalFiles -eq 0) { continue }
        $homogeneity = $dominantCount / $totalFiles
        
        # LOGIC DECISION
        
        # CASE A: WRONG YEAR (High Homogeneity)
        # If >90% files belong to another year, move the whole folder
        if ($homogeneity -gt 0.9 -and $dominantYear -ne $parentYear -and $parentYear -ne 0) {
            # Special case for "2018 e pre": if files are <= 2018, it's fine
            if ($yFolder.Name -like "*pre" -and $dominantYear -le 2018) { continue }

            $targetPath = Join-Path $RootPath "$dominantYear\$($sub.Name)"
            $action = "MOVE FOLDER"
            $msg = "Folder '$($sub.Name)' ($parentYear) -> $dominantYear (Contains $dominantCount/$totalFiles files of $dominantYear)"
            
            Write-Host "[$action] $msg" -ForegroundColor Yellow
            $ActionsLog += "$action : $msg"

            if ($Execute) {
                # Create destination year folder if missing
                $destYearDir = Join-Path $RootPath "$dominantYear"
                if (-not (Test-Path $destYearDir)) { New-Item -Path $destYearDir -ItemType Directory | Out-Null }
                
                # Move
                if (Test-Path $targetPath) {
                    Write-Host "  [SKIP] Target already exists: $targetPath" -ForegroundColor Red
                }
                else {
                    Move-Item -Path $sub.FullName -Destination $targetPath
                }
            }
        }
        # CASE B: MIXED CONTENT (Split required)
        elseif ($homogeneity -le 0.9) {
            $action = "SPLIT MIXED"
            # Format stats for display
            $statStr = ($stat.GetEnumerator() | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ", "
            $msg = "Folder '$($sub.Name)' ($parentYear) is MIXED. Stats: [$statStr]"
            
            Write-Host "[$action] $msg" -ForegroundColor Magenta
            $ActionsLog += "$action : $msg"

            if ($Execute) {
                # Generate Analysis Report
                $reportPath = Join-Path $sub.FullName "ANALYSIS_REPORT.txt"
                $reportContent = "ANALYSIS FOR: $($sub.Name)`r`nTotal Files: $totalFiles`r`nDate Range: $minDate to $maxDate`r`nYear Stats:`r`n$($stat | Out-String)`r`nOutliers/Notes:`r`nFolder needs splitting."
                Set-Content -Path $reportPath -Value $reportContent

                # Create Subfolders and Move Files
                foreach ($yearKey in $stat.Keys) {
                    $yearSubPath = Join-Path $sub.FullName "$yearKey"
                    if (-not (Test-Path $yearSubPath)) { New-Item -Path $yearSubPath -ItemType Directory | Out-Null }
                    
                    # Move files of this year
                    Get-ChildItem -Path $sub.FullName -File | Where-Object { (Get-MediaYear $_) -eq $yearKey } | Move-Item -Destination $yearSubPath
                }
            }
        }
    }
}

# 2. Merge Candidates Analysis
Write-Host "`n=== POTENTIAL MERGE CANDIDATES ===" -ForegroundColor Cyan
foreach ($name in $MergeCandidates.Keys) {
    if ($MergeCandidates[$name].Count -gt 1) {
        Write-Host "Duplicate Folder Name found in multiple years:" -ForegroundColor Yellow
        $MergeCandidates[$name] | ForEach-Object { Write-Host "  - $_" }
    }
}
