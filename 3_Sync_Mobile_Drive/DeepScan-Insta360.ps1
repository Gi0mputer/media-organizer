# Deep scan of entire E:\ for Insta360 files

Write-Host "Scanning entire E:\ for .insv/.insp/.dng files..." -ForegroundColor Yellow

$allPcFiles = Get-ChildItem -Path "E:\" -Recurse -File -Include "*.insv", "*.insp", "*.dng" -ErrorAction SilentlyContinue | 
Where-Object { $_.FullName -notmatch '\\_trash\\' }

Write-Host "Found $($allPcFiles.Count) Insta360 files on entire E:\" -ForegroundColor Green

# Create map
$pcMap = @{}
foreach ($f in $allPcFiles) {
    $key = "$($f.Name)|$($f.Length)"
    if (-not $pcMap.ContainsKey($key)) {
        $pcMap[$key] = $f.FullName
    }
}

# Load phone report
$report = Get-Content "$PSScriptRoot\insta360_report.json" | ConvertFrom-Json

# Re-check
$stillNeed = @()
foreach ($n in $report.NeedToSave) {
    $key = "$($n.Name)|$($n.Size)"
    if (-not $pcMap.ContainsKey($key)) {
        $stillNeed += $n
    }
}

Write-Host "`nAfter full E:\ scan:" -ForegroundColor Cyan
Write-Host "  Files truly unique: $($stillNeed.Count)" -ForegroundColor Red

if ($stillNeed.Count -lt $report.NeedToSave.Count) {
    $found = $report.NeedToSave.Count - $stillNeed.Count
    Write-Host "  Found $found additional files on E:\ (outside Insta360 folders)" -ForegroundColor Green
}

# Update report
$finalReport = @{
    Timestamp   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    TrulyUnique = $stillNeed
    Summary     = @{
        TrulyUniqueCount = $stillNeed.Count
        SpaceToSaveGB    = [math]::Round(($stillNeed | Measure-Object -Property Size -Sum).Sum / 1GB, 2)
    }
}

$finalReport | ConvertTo-Json -Depth 5 | Set-Content "$PSScriptRoot\insta360_final_report.json"
Write-Host "`nFinal report saved." -ForegroundColor Gray

Write-Host "`n=== FILES TO TRANSFER (First 20) ===" -ForegroundColor Yellow
$stillNeed | Select-Object -First 20 Name, @{Label = "Size(MB)"; Expression = { [math]::Round($_.Size / 1MB, 2) } }
